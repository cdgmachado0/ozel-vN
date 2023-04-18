// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { UC, ONE, ZERO } from "unchecked-counter/UC.sol";
import '../AppStorage.sol';
import "forge-std/console.sol";
import '../../libraries/LibHelpers.sol';
import '../../libraries/LibDiamond.sol';
import '../../libraries/LibCommon.sol';
import '../../Errors.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
// import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '../../libraries/oracle/OracleLibrary.sol';
import '../../libraries/oracle/FullMath.sol';
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

// import 'hardhat/console.sol';

//add modularity to add and remove chainlink feeds
//add uniswap and trellors oracles as a fallback
contract ozOracleFacet {

    AppStorage s;

    using LibHelpers for *;

    int256 private constant EIGHT_DEC = 1e8;
    int256 private constant NINETN_DEC = 1e19;

    // error NotFeed(address feed);

    //**** MAIN ******/

    function getEnergyPrice() external view returns(uint256) {

        (DataInfo[] memory infoFeeds, int basePrice) = _getDataFeeds();
      
        int256 volIndex = getVolatilityIndex();
        int256 netDiff;

        uint256 length = infoFeeds.length;
        for (UC i=ZERO; i < uc(length); i = i + ONE) {
            DataInfo memory info = infoFeeds[i.unwrap()];

            netDiff += _setPrice(
                info, address(info.feed) == address(s.ethFeed) ? int256(0) : volIndex
            );
        }

        return uint256(basePrice + ( (netDiff * basePrice) / (100 * EIGHT_DEC) ));
    }



    function _getDataFeeds() private view returns(DataInfo[] memory, int256) {
        uint256 length = s.priceFeeds.length;
        DataInfo[] memory infoFeeds = new DataInfo[](length);

        for (UC i=ZERO; i < uc(length); i = i + ONE) {
            uint256 j = i.unwrap();
            (uint80 id, int256 value,,,) = s.priceFeeds[j].latestRoundData();

            DataInfo memory info = DataInfo({
                roundId: id,
                value: value,
                feed: s.priceFeeds[j]
            });
            infoFeeds[j] = info;
        }

        //ethPrice feed
        int256 basePrice = infoFeeds[1].value.calculateBasePrice();

        return (infoFeeds, basePrice); 
    }

    //-------------------

    function getUni() public view returns(uint) { //returns(int56[] memory ticks, uint160[] memory secs)
        address ethUsdcPool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
        address wethAddr = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdcAddr = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

        //-------------
        IUniswapV3Pool pool = IUniswapV3Pool(ethUsdcPool);
        // uint32[] memory secsAgo = new uint32[](1);
        // secsAgo[0] = 0;

        // (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = pool.observe(secsAgo);
        // return (tickCumulatives, secondsPerLiquidityCumulativeX128s);

        //---------
        (int24 tick,) = OracleLibrary.consult(ethUsdcPool, uint32(10));
        uint amountOut = OracleLibrary.getQuoteAtTick(
            tick, 10, wethAddr, usdcAddr
        );
        return amountOut; 
        //------------
        // (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        // uint256 price = getPriceX96FromSqrtPriceX96(sqrtPriceX96);
        // return price;

    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns(uint256 priceX96) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }




    //------------------

    function _setPrice(
        DataInfo memory feedInfo_, 
        int256 volIndex_
    ) private view returns(int256) 
    {
        if (address(feedInfo_.feed) != address(s.ethFeed)) {
            int256 currPrice = feedInfo_.value;
            int256 netDiff = currPrice - feedInfo_.roundId.getPrevFeed(feedInfo_.feed);
            return ( (netDiff * 100 * EIGHT_DEC) / currPrice ) * (volIndex_ / NINETN_DEC);
        } else {
            int256 prevEthPrice = feedInfo_.roundId.getPrevFeed(feedInfo_.feed);
            int256 netDiff = feedInfo_.value - prevEthPrice;
            return (netDiff * 100 * EIGHT_DEC) / prevEthPrice;
        }
    }


    function getVolatilityIndex() public view returns(int256) {
        (, int256 volatility,,,) = s.volatilityFeed.latestRoundData();
        return volatility;
    }

    function changeVolatilityIndex(AggregatorV3Interface newFeed_) external {
        LibDiamond.enforceIsContractOwner();
        s.volatilityFeed = newFeed_;
    }

    function addFeed(AggregatorV3Interface newFeed_) external {
        LibDiamond.enforceIsContractOwner();

        int256 index = s.priceFeeds.indexOf(address(newFeed_));
        if (index != -1) revert AlreadyFeed(address(newFeed_));

        s.priceFeeds.push(newFeed_);
    }

    function removeFeed(AggregatorV3Interface toRemove_) external {
        LibDiamond.enforceIsContractOwner();

        int256 index = s.priceFeeds.indexOf(address(toRemove_));
        if (index == -1) revert NotFeed(address(toRemove_));

        LibCommon.remove(s.priceFeeds, toRemove_);
    }

    function getPriceFeeds() external view returns(address[] memory feeds) {
        uint256 length = s.priceFeeds.length;
        feeds = new address[](length);

        for (UC i=ZERO; i < uc(length); i = i + ONE) {
            uint256 j = i.unwrap();
            feeds[j] = address(s.priceFeeds[j]);
        }
    }


}





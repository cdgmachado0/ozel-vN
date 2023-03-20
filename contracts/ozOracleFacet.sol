// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
// import 'solmate/src/utils/FixedPointMathLib.sol';
import './AppStorage.sol';

import 'hardhat/console.sol';

contract ozOracleFacet {

    AppStorage s;

    // AggregatorV3Interface private wtiFeed;
    // AggregatorV3Interface private volatilityFeed;
    // AggregatorV3Interface private ethFeed;
    // AggregatorV3Interface private goldFeed;

    int256 private constant EIGHT_DEC = 1e8;
    int256 private constant NINETN_DEC = 1e19;

    // int eETHprice = 1000 * EIGHT_DEC;
    int constant BASE = 1e7;


    struct DataInfo {
        uint80 roundId;
        int256 value;
    }

    struct Data {
        DataInfo volIndex;
        DataInfo wtiPrice;
        DataInfo ethPrice;
        DataInfo goldPrice;
    }


    
    // constructor(
    //     address wtiFeed_,
    //     address volatilityFeed_,
    //     address ethUsdFeed_,
    //     address goldFeed_
    // ) {
    //     wtiFeed = AggregatorV3Interface(wtiFeed_);
    //     volatilityFeed = AggregatorV3Interface(volatilityFeed_);
    //     ethFeed = AggregatorV3Interface(ethUsdFeed_);
    //     goldFeed = AggregatorV3Interface(goldFeed_);
    // }


    //**** MAIN ******/
    function getLastPrice() external view returns(uint256) {
        (Data memory data, int basePrice) = _getDataFeeds();
        int256 volIndex = data.volIndex.value;

        int256 implWti = _setImplWti(data.wtiPrice, volIndex, s.wtiFeed); 
        int256 implGold = _setImplGold(data.goldPrice, volIndex, s.goldFeed);
        int256 implEth = _setImplEth(data.ethPrice, s.ethFeed);

        int256 netDiff = implWti + implEth + implGold;

        return uint256(basePrice + ( (netDiff * basePrice) / (100 * EIGHT_DEC) ));
    }


    function _getDataFeeds() private view returns(Data memory data, int basePrice) {
        (,int256 volatility,,,) = s.volatilityFeed.latestRoundData();
        (uint80 wtiId, int256 wtiPrice,,,) = s.wtiFeed.latestRoundData();
        (uint80 ethId, int256 ethPrice,,,) = s.ethFeed.latestRoundData();
        (uint80 goldId, int256 goldPrice,,,) = s.goldFeed.latestRoundData();

        basePrice = _calculateBasePrice(ethPrice);

        data = Data({
            volIndex: DataInfo({
                roundId: 0,
                value: volatility
            }),
            wtiPrice: DataInfo({
                roundId: wtiId,
                value: wtiPrice
            }),
            ethPrice: DataInfo({
                roundId: ethId,
                value: ethPrice
            }),
            goldPrice: DataInfo({
                roundId: goldId,
                value: goldPrice
            })
        });
    }


     function _getPrevFeed(
        uint80 roundId_, 
        AggregatorV3Interface feed_
    ) private view returns(int256) {
        (,int256 prevPrice,,,) = feed_.getRoundData(roundId_ - 1);
        return prevPrice;
    }

    function _setImplWti(
        DataInfo memory wtiPrice_,
        int256 volIndex_,
        AggregatorV3Interface feed_
    ) private view returns(int256) {
        int256 currWti = wtiPrice_.value;
        int256 netDiff = currWti - _getPrevFeed(wtiPrice_.roundId, feed_);
        return ( (netDiff * 100 * EIGHT_DEC) / currWti ) * (volIndex_ / NINETN_DEC);
    }


    function _setImplGold(
        DataInfo memory goldPrice_,
        int256 volIndex_,
        AggregatorV3Interface feed_
    ) private view returns(int256) {
        int256 currGold = goldPrice_.value;
        int256 netDiff = currGold - _getPrevFeed(goldPrice_.roundId, feed_);
        return ( (netDiff * 100 * EIGHT_DEC) / currGold ) * (volIndex_ / NINETN_DEC);
    }


    function _setImplEth(
        DataInfo memory ethPrice_,
        AggregatorV3Interface feed_
    ) private view returns(int256) {
        int256 prevEthPrice = _getPrevFeed(ethPrice_.roundId, feed_);
        int256 netDiff = ethPrice_.value - prevEthPrice;
        return (netDiff * 100 * EIGHT_DEC) / prevEthPrice;
    }

    function _calculateBasePrice(int256 ethPrice_) private pure returns(int256) {
        return ( (100 * EIGHT_DEC * ethPrice_) / 10 * EIGHT_DEC ) / BASE;
    }
    

}





pragma solidity 0.8.19;




interface ozIDiamond {

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    enum FacetCutAction {Add, Replace, Remove}


    function diamondCut(FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) external;

    function getLastPrice() external view returns(uint256);

}
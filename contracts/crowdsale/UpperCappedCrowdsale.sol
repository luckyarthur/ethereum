pragma solidity ^0.4.18;

import "./Crowdsale.sol";


/**
* @dev Parent crowdsale contract is extended with support for cap in tokens
* Based on references from OpenZeppelin: https://github.com/OpenZeppelin/zeppelin-solidity
* 
*/
contract UpperCappedCrowdsale is Crowdsale {

    uint256 public tokensUpperCap;

    function UpperCappedCrowdsale(uint256 _tokensUpperCap) public {
        tokensUpperCap = _tokensUpperCap;
    }

    // overriding Crowdsale#validPurchase to add extra tokens cap logic
    // @return true if investors can buy at the moment
    function validPurchase() internal constant returns(bool) {
        uint256 tokens = token.totalSupply().add(msg.value.mul(rate));
        bool withinCap = tokens <= tokensUpperCap;
        return super.validPurchase() && withinCap;
    }

    // overriding Crowdsale#hasEnded to add tokens cap logic
    // @return true if crowdsale event has ended
    function hasEnded() public constant returns(bool) {
        bool capReached = token.totalSupply() >= tokensUpperCap;
        return super.hasEnded() || capReached;
    }

}
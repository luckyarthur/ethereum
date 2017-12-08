pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/BurnableToken.sol";
import "zeppelin-solidity/contracts/token/PausableToken.sol";
import "zeppelin-solidity/contracts/token/CappedToken.sol";

/*******************************************************************************************
 * Based on references from OpenZeppelin: https://github.com/OpenZeppelin/zeppelin-solidity
 *******************************************************************************************/
contract IHTTokenFive is BurnableToken, PausableToken, CappedToken(IHTTokenFive.MAX_TOKENS) {
    //
    // CONSTANTS
    string  public constant name = "IHT Test Token v5";
    string  public constant symbol = "IHTFI";
    string  public constant version = "0.6";
    uint256   public constant DECIMALS = 4;
    uint256 public constant MAX_TOKENS = 1 * (10**8) * (10**DECIMALS);              // 100 Million IHTTestFive

    //
    // VARIABLES
    uint256 public privateHoldingPeriodEnds = 0;
    uint256 public presaleHoldingPeriodEnds = 0;

    // COMPLEX TYPE
    // This represent private, presale balance for investors.
    struct PreICOBalance {
        bool participated;          // if true, this account has participated in private, presale
        uint256 privateBalance;     // amount purchased in private sale - locked for 3 months (see constant)
        uint256 presaleBalance;     // amount purchased in presale - locked for 6 months (see constant)
    }

    // This declares a state variable that
    // stores a `PreICOPurchase` struct for each possible address.
    mapping(address => PreICOBalance) public PreICOPurchase;

    // Events
    event PrivateEndTimeChange(uint256 _endTime);
    event PresaleEndTimeChange(uint256 _endTime);

    //
    // MODIFIERS make sure balance are free of retriction to trade

    /*
     *@dev Fix for the ERC20 short address attack.
     */
    modifier checkPayloadSize(uint256 size) {
        require(msg.data.length >= size + 4);
        _;
    }
    
    modifier privateBalanceCheck(address _address, uint256 _value) {
        if (PreICOPurchase[_address].participated) {
            uint256 privateBalance = 0;
            
            // add private balance if they are still under restricted trading period
            if (now <= privateHoldingPeriodEnds) {
                privateBalance += PreICOPurchase[_address].privateBalance;
            }
        
            // add private balance if they are still under restricted trading period
            if (now <= presaleHoldingPeriodEnds) {
                privateBalance += PreICOPurchase[_address].presaleBalance;
            }
        
            /* check to make sure there is enough unrestricted balance to fund transfer */
            require ((balances[_address] - privateBalance) > _value);
        }
        _;
    }
    
    //
    // Setters
    /**
    * @dev Sets Private Holding Period Ends
    * @param _endTime defines when Private purchases are free to trade
    */
    function setPrivateEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime != 0x0);
        privateHoldingPeriodEnds = _endTime;
        
        PrivateEndTimeChange(_endTime);
    }
    
    /**
    * @dev Sets Presale Holding Period Ends
    * @param _endTime defines when Presale purchases are free to trade
    */
    function setPresaleEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime != 0x0);
        presaleHoldingPeriodEnds = _endTime;
        
        PresaleEndTimeChange(_endTime);
    }

    //
    // CONSTRUCTOR
    function IHTTokenFive(uint256 _privateHoldingEnds, uint256 _presaleHoldingEnds) public {        
        require(_privateHoldingEnds > 0);
        require(_presaleHoldingEnds > 0);

        privateHoldingPeriodEnds = _privateHoldingEnds;
        presaleHoldingPeriodEnds = _presaleHoldingEnds;
    }


    function adjustPreICOBalance(address _address, uint256 _value) internal {
        uint256 runningValue = _value;
        uint256 preICOBalance = 0;
    
        // spend presaleBalance first as they have longer restricted trading period (6 months)
        if (runningValue > 0 && now > presaleHoldingPeriodEnds) {
            preICOBalance = PreICOPurchase[_address].presaleBalance;
            if ((preICOBalance - runningValue) >= 0) {
                PreICOPurchase[_address].presaleBalance -= runningValue;
                runningValue = 0;
            } else {
                PreICOPurchase[_address].presaleBalance = 0;
                runningValue -= preICOBalance;            
            }
        }
    
        // spend privateBalance next as they have shorter restricted trading period (3 months)
        if (runningValue > 0 && now > privateHoldingPeriodEnds) {
            preICOBalance = PreICOPurchase[_address].privateBalance;
            if ((preICOBalance - runningValue) >= 0) {
                PreICOPurchase[_address].privateBalance -= runningValue;
                runningValue = 0;
            } else {
                PreICOPurchase[_address].privateBalance = 0;
                runningValue -= preICOBalance;            
            }
        }
    }

    
    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
//    function transfer(address _to, uint256 _value) public checkPayloadSize(2 * 32)  returns (bool) {
    function transfer(address _to, uint256 _value) public privateBalanceCheck(msg.sender, _value) returns (bool) {
        require(_to != address(0));

        /* call super to do the transfer */    
        bool fReturn = super.transfer(_to, _value);    
        
        /* adjust the amount in the (un)Locked mapping to deduct the amount transfer */
        adjustPreICOBalance(msg.sender, _value);
        
        return fReturn;
    }
  
    
    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
//    function transferFrom(address _from, address _to, uint256 _value) public checkPayloadSize(3 * 32) returns (bool) {
    function transferFrom(address _from, address _to, uint256 _value) public privateBalanceCheck(_from, _value) returns (bool) {
        require(_to != address(0));

        /* call super to do the transfer */    
        bool fReturn = super.transfer(_to, _value);    
    
        /* adjust the amount in the (un)Locked mapping to deduct the amount transfer */
        adjustPreICOBalance(_from, _value);
        
        return fReturn;
    }
  
    /**
     * @dev Function to mint Presale (6 months holding period) tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mintPresale(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        bool fReturn = super.mint(_to, _amount);
        
        if (fReturn) {
            PreICOBalance storage pb = PreICOPurchase[_to];
            pb.presaleBalance += _amount;
            pb.participated = true;
        }
        
        return fReturn;
    }

    /**
     * @dev Function to mint Private (3 month holding period) tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mintPrivate(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        bool fReturn = super.mint(_to, _amount);
        
        if (fReturn) {
            PreICOBalance storage pb = PreICOPurchase[_to];
            pb.privateBalance += _amount;
            pb.participated = true;
        }
        
        return fReturn;
    }
  

    /**
     * @dev Override MintableToken.finishMinting() to add canMint modifier
     * Token is no longer mintable after crowdsale (at finalization, token is minted to max, assign to owner)
     */
    function finishMinting() onlyOwner canMint public returns(bool) {
        return super.finishMinting();
    }
}

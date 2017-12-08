pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Crowdsale.sol";
import "./FinalizableCrowdsale.sol";
import "./UpperCappedCrowdsale.sol";
import "./PausableCrowdsale.sol";
import "../token/IHTTokenFive.sol";

/*******************************************************************************************
 * @dev IHT Crowdsale contract. 
 * Based on references from OpenZeppelin: https://github.com/OpenZeppelin/zeppelin-solidity
 *******************************************************************************************/
contract IHTCSFiveOne is FinalizableCrowdsale, UpperCappedCrowdsale(IHTCSFiveOne.MAX_TOKENS_FOR_SALE), PausableCrowdsale(false) {

    // Constants
    uint256 public constant DECIMALS = 4;
    uint256 public constant MAX_TOKENS_AVAILABLE = 1 * (10**8) * (10**DECIMALS);        // 100Mil IHTTokenFive total
    uint256 public constant MAX_TOKENS_FOR_SALE = 35 * (10**6) * (10**DECIMALS);        // 35Mil IHTTokenFive

    // Events
    event RateChange(uint256 rate);
    event WalletChange(address indexed newWallet);
    event EndTimeChange(uint256 endTime);

    /**
    * @dev Sets IHTTokenFive to Ether rate
    * @param _rate defines IHTv5/ETH rate: 1 ETH = _rate * IHTTokenFive
    */
    function setRate(uint256 _rate) external onlyOwner {
        require(_rate != 0x0);
        rate = _rate;
        
        RateChange(_rate);
    }

    /**
    * @dev Allows to adjust the crowdsale end time
    */
    function setEndTime(uint256 _endTime) external onlyOwner {
        require(!isFinalized);
        require(_endTime >= startTime);
        require(_endTime >= now);
        endTime = _endTime;
        
        EndTimeChange(_endTime);
    }

    /**
    * @dev Sets the wallet to forward ETH collected funds
    */
    function setWallet(address _wallet) external onlyOwner {
        require(_wallet != 0x0);
        wallet = _wallet;
        
        WalletChange(_wallet);
    }

    /**
    * @dev Contructor
    * @param _startTime startTime of crowdsale
    * @param _endTime endTime of crowdsale
    * @param _rate IHT / ETH rate
    * @param _wallet wallet to forward the collected funds
    * @param _token token contract to link to this crowdsale contract
    */
    function IHTCSFiveOne(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        address _wallet,
        address _token
    ) public
        Crowdsale(_startTime, _endTime, _rate, _wallet, _token)
    {
        token.pause();              // No token trade other than this crowdsale contract prior ICO period ends
    }

    // Overrided methods

    /**
    * @dev Finalizes the crowdsale
    */
    function finalization() internal {
        super.finalization();

        // Mint tokens up to MAX_TOKENS_AVAILABLE and assign to owner wallet
        if (token.totalSupply() < MAX_TOKENS_AVAILABLE) {
            uint256 tokens = MAX_TOKENS_AVAILABLE - token.totalSupply();  // Need to use SafeMath libray for subtraction
            token.mint(wallet, tokens);                                   // Mint up to total cap and assign to owner
        }

        // Stop minting after ICO period ends
        token.finishMinting();

        // take onwership over IHTTestThree contract
        token.transferOwnership(owner);

        // Token is now free to trade
        token.unpause();  
    }

    /**
    * @dev Mint unrestricted tokens - ICO or post ICO 
    */
    function mintToken(address beneficiary, uint256 tokens) public onlyOwner {
        require(beneficiary != 0x0);
        require(tokens > 0);
        require(now <= endTime);                                    // Crowdsale (without startTime check)
        require(!isFinalized);                                      // FinalizableCrowdsale
        require(token.totalSupply().add(tokens) <= tokensUpperCap); // UpperCappedCrowdsale
        
        token.mint(beneficiary, tokens);
    }
}

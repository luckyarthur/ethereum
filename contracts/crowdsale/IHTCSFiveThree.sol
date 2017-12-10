pragma solidity ^0.4.18;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    Unpause();
  }
}


/*******************************************************************************************
 * Token contract begins
 * Based on references from OpenZeppelin: https://github.com/OpenZeppelin/zeppelin-solidity
 *******************************************************************************************/
interface Token { 
    function mint(address _to, uint256 _amount) public returns (bool);
    function transferOwnership(address newOwner) public;
    function finishMinting() public returns(bool);
    function totalSupply() public constant returns (uint256 supply);
}

/*******************************************************************************************
 * @dev IHT Crowdsale contract. 
 * Based on references from OpenZeppelin: https://github.com/OpenZeppelin/zeppelin-solidity
 *******************************************************************************************/
contract IHTCSFiveThree is Ownable, Pausable {
    using SafeMath for uint256;
    
    /**************************************************************************
     * Constants
     **************************************************************************/
    uint256 public constant DECIMALS = 4;
    uint256 public constant MAX_TOKENS_AVAILABLE = 1 * (10**8) * (10**DECIMALS);        // 100Mil IHTTokenFive total
    uint256 public constant MAX_TOKENS_FOR_SALE = 35 * (10**6) * (10**DECIMALS);        // 35Mil IHTTokenFive

    /**************************************************************************
     * Variables
     **************************************************************************/
    Token public token;                         // Deployed token being sold

    uint256 public startTime;                   // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public endTime;
    address public wallet;                      // Address where funds are collected
    uint256 public rate;                        // # token units a buyer gets per wei
    uint256 public weiRaised;                   // Amount of raised money in wei

    bool public isFinalized = false;            // Finalization

    /**************************************************************************
     * Events
     **************************************************************************/
    event RateChange(uint256 rate);
    event WalletChange(address indexed newWallet);
    event EndTimeChange(uint256 endTime);

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event Finalized();

    /**************************************************************************
     * Event Implementation
     **************************************************************************/
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

    /**************************************************************************
     * Constructor
     **************************************************************************/
    /**
    * @dev Contructor
    * @param _startTime startTime of crowdsale
    * @param _endTime endTime of crowdsale
    * @param _rate IHT / ETH rate
    * @param _wallet wallet to forward the collected funds
    * @param _token token contract to link to this crowdsale contract
    */
    function IHTCSFiveThree(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        address _wallet,
        address _token
    ) public
    {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != address(0));
        require(_token != 0x0);

        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
        wallet = _wallet;        
        
        token = Token(_token);
    }

    // fallback function don't accept purchase
    function () external payable {
        revert();
    }

    /**************************************************************************
     * Finalization methods
     **************************************************************************/
    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() onlyOwner public {
        require(!isFinalized);
        require(hasEnded());

        finalization();
        Finalized();

        isFinalized = true;
    }

    // Overrided methods
    /**
    * @dev Finalizes the crowdsale
    */
    function finalization() internal {
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
        // token.unpause();  
    }

    /**************************************************************************
     * Token purchase methods
     **************************************************************************/
    // default buy function
    function buy() public payable {
        buyTokens(msg.sender);
    }

    // low level token purchase function
    function buyTokens(address beneficiary) public whenNotPaused payable {
        require(beneficiary != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;

        uint256 tokens = token.totalSupply().add(msg.value.mul(rate));
        bool withinCap = tokens <= MAX_TOKENS_FOR_SALE;
        
        return withinPeriod && nonZeroPurchase && withinCap && !paused;
    }

    // overriding Crowdsale#hasEnded to add tokens cap logic
    // @return true if crowdsale event has ended
    function hasEnded() public constant returns(bool) {
        bool capReached = token.totalSupply() >= MAX_TOKENS_FOR_SALE;
        return now > endTime || capReached;
    }
}

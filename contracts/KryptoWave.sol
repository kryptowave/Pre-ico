pragma solidity ^0.4.19;

contract PresaleToken
{
    /// Fields:
    string public constant name = "Kryptowave Presale Token";
    string public constant symbol = "HASHX";
    uint public constant decimals = 18;
    uint public constant PRICE = 4000;  // per 1 Ether

    //  price
    // Cap is 3000 ETH
    // 1 eth = 4000;  presale Wave tokens
    uint public constant TOKEN_SUPPLY_LIMIT = PRICE * 3000 * (1 ether / 1 wei);

    enum State{
        Init,
        Running,
        Paused,
        Migrating,
        Migrated
    }

    State public currentState = State.Init;
    uint public totalSupply = 0; // amount of tokens already sold

    // Token manager has exclusive priveleges to call administrative
    // functions on this contract.
    address public tokenManager = 0;

    // Crowdsale manager has exclusive priveleges to burn presale tokens.
    address public crowdsaleManager = 0;

    mapping (address => uint256) private balance;

    /// Modifiers:
    modifier onlyTokenManager()     { require(msg.sender == tokenManager); _; }
    modifier onlyCrowdsaleManager() { require(msg.sender == crowdsaleManager); _; }
    modifier onlyInState(State state){ require(state == currentState); _; }

    /// Events:
    event LogBuy(address indexed owner, uint value);
    event LogBurn(address indexed owner, uint value);
    event LogStateSwitch(State newState);

    /// Functions:
    /// @dev Constructor
    /// @param _tokenManager Token manager address.
    function PresaleToken(address _tokenManager)
    {
        require(_tokenManager != 0);

        tokenManager = _tokenManager;
    }

    function buyTokens(address _buyer) payable onlyInState(State.Running)
    {
        require(msg.value != 0);
        uint newTokens = msg.value * PRICE;

        require(totalSupply + newTokens <= TOKEN_SUPPLY_LIMIT);

        balance[_buyer] += newTokens;
        totalSupply += newTokens;

        LogBuy(_buyer, newTokens);
    }

    /// @dev Returns number of tokens owned by given address.
    /// @param _owner Address of token owner.
    function burnTokens(address _owner) public onlyCrowdsaleManager onlyInState(State.Migrating)
    {
        uint tokens = balance[_owner];
        require(tokens != 0);

        balance[_owner] = 0;
        totalSupply -= tokens;

        LogBurn(_owner, tokens);

        // Automatically switch phase when migration is done.
        if(totalSupply == 0)
        {
            currentState = State.Migrated;
            LogStateSwitch(State.Migrated);
        }
    }

    /// @dev Returns number of tokens owned by given address.
    /// @param _owner Address of token owner.
    function balanceOf(address _owner) constant returns (uint256)
    {
        return balance[_owner];
    }

    function setPresaleState(State _nextState) public onlyTokenManager
    {
        // Init -> Running
        // Running -> Paused
        // Running -> Migrating
        // Paused -> Running
        // Paused -> Migrating
        // Migrating -> Migrated
        bool canSwitchState
        =  (currentState == State.Init && _nextState == State.Running)
        || (currentState == State.Running && _nextState == State.Paused)
        // switch to migration phase only if crowdsale manager is set
        || ((currentState == State.Running || currentState == State.Paused)
        && _nextState == State.Migrating
        && crowdsaleManager != 0x0)
        || (currentState == State.Paused && _nextState == State.Running)
        // switch to migrated only if everyting is migrated
        || (currentState == State.Migrating && _nextState == State.Migrated
        && totalSupply == 0);

        require(canSwitchState);

        currentState = _nextState;
        LogStateSwitch(_nextState);
    }

    function withdrawEther() public onlyTokenManager
    {
        if(this.balance > 0)
        {
            require(crowdsaleManager.send(this.balance));
        }
    }

    /// Setters/getters
    function setTokenManager(address _mgr) public onlyTokenManager
    {
        tokenManager = _mgr;
    }

    function setCrowdsaleManager(address _mgr) public onlyTokenManager
    {
        // You can't change crowdsale contract when migration is in progress.
        require(currentState != State.Migrating);

        crowdsaleManager = _mgr;
    }

    function getTokenManager()constant returns(address)
    {
        return tokenManager;
    }

    function getCrowdsaleManager()constant returns(address)
    {
        return crowdsaleManager;
    }

    function getCurrentState()constant returns(State)
    {
        return currentState;
    }

    function getPrice()constant returns(uint)
    {
        return PRICE;
    }

    function getTotalSupply()constant returns(uint)
    {
        return totalSupply;
    }


    // Default fallback function
    function() payable
    {
        buyTokens(msg.sender);
    }
}
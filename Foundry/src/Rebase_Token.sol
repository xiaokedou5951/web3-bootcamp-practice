// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RebaseToken
 * @dev 通缩型 Rebase Token 实现
 * 起始发行量为 1 亿，每年通缩 1%
 * 参考 Ampleforth 的实现原理
 */
contract RebaseToken {
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 100_000_000 * 10**18;
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    string public name = "Rebase Deflation Token";
    string public symbol = "RDT";
    uint8 public decimals = 18;
    
    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    
    uint256 public lastRebaseTime;
    uint256 public rebaseCount;
    address public owner;
    
    uint256 private constant DEFLATION_RATE = 99;
    uint256 private constant RATE_DENOMINATOR = 100;
    uint256 private constant REBASE_INTERVAL = 365 days;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 indexed epoch, uint256 totalSupply);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        lastRebaseTime = block.timestamp;
        _gonBalances[msg.sender] = TOTAL_GONS;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view returns (uint256) {
        return _gonBalances[who] / _gonsPerFragment;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(to != address(this), "Transfer to contract");
        
        uint256 gonValue = value * _gonsPerFragment;
        _gonBalances[msg.sender] -= gonValue;
        _gonBalances[to] += gonValue;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(to != address(this), "Transfer to contract");
        
        _allowances[from][msg.sender] -= value;
        uint256 gonValue = value * _gonsPerFragment;
        _gonBalances[from] -= gonValue;
        _gonBalances[to] += gonValue;
        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _allowances[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 oldValue = _allowances[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowances[msg.sender][spender] = 0;
        } else {
            _allowances[msg.sender][spender] = oldValue - subtractedValue;
        }
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }

    function rebase() external onlyOwner {
        require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, "Rebase too early");
        _rebase();
    }

    function manualRebase() external onlyOwner {
        _rebase();
    }

    function _rebase() internal {
        rebaseCount++;
        uint256 newTotalSupply = (_totalSupply * DEFLATION_RATE) / RATE_DENOMINATOR;
        _totalSupply = newTotalSupply;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        lastRebaseTime = block.timestamp;
        emit Rebase(rebaseCount, _totalSupply);
    }

    function gonsPerFragment() external view returns (uint256) {
        return _gonsPerFragment;
    }

    function canRebase() external view returns (bool) {
        return block.timestamp >= lastRebaseTime + REBASE_INTERVAL;
    }

    function nextRebaseTime() external view returns (uint256) {
        return lastRebaseTime + REBASE_INTERVAL;
    }

    function gonBalanceOf(address who) external view returns (uint256) {
        return _gonBalances[who];
    }
}
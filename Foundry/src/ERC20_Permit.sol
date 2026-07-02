// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入EIP712标准所需的接口和库
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract ERC20Permit {
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 
    
    // EIP2612所需的状态变量
    bytes32 private immutable _DOMAIN_SEPARATOR;
    bytes32 private constant _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) private _nonces;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "AndyToken";
        symbol = "AnToken";
        decimals = 18;
        totalSupply = 100000000 * 10**uint256(decimals); // 100,000,000 tokens
        
        balances[msg.sender] = totalSupply;
        
        // 初始化域分隔符
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "ERC20: approve to the zero address");
        
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {        
        return allowances[_owner][_spender];
    }
    
    // EIP2612 permit函数实现
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner]++,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash));

        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner, "ERC20Permit: invalid signature");

        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // 获取用户当前的nonce
    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner];
    }

    // 获取域分隔符
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }
}
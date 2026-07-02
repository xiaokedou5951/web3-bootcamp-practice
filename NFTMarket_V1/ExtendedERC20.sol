// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ITokenReceiver.sol";

// 扩展的ERC20合约，添加带有回调功能的转账函数
contract ExtendedERC20 {
    string private _name; 
    string private _symbol; 
    uint8 private  _decimals; 

    uint256 private _totalSupply; 

    mapping (address => uint256) private _balances; 

    mapping (address => mapping (address => uint256)) private _allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // write your code here
        // set name,symbol,decimals,totalSupply
        _name = "BaseERC20";
        _symbol = "BERC20";
        _decimals = 18;
        _totalSupply = 100000000 * 10**uint256(_decimals); // 100,000,000 tokens
        
        _balances[msg.sender] = _totalSupply;  
    }
    function name() public view returns (string memory){
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        _balances[msg.sender] -= _value;
        _balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

    // 添加带有回调功能的转账函数
    function transferWithCallback(address _to, uint256 _value) public returns (bool success) {
        require(_balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        _balances[msg.sender] -= _value;
        _balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        
        // 如果接收方是合约，调用其tokensReceived方法
        if (isContract(_to)) {
            try ITokenReceiver(_to).tokensReceived(msg.sender, _value, "") returns (bool) {
                // 回调成功
            } catch {
                // 回调失败，但不回滚交易
            }
        }
        
        return true;
    }

    // 添加带有回调功能的转账函数，支持传递数据
    function transferWithCallbackAndData(address _to, uint256 _value, bytes calldata _data) external returns (bool){
        address from = tx.origin;
        require(_balances[from] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        _balances[from] -= _value;
        _balances[_to] += _value;

        emit Transfer(from, _to, _value);
        
        // 如果接收方是合约，调用其tokensReceived方法
        if (isContract(_to)) {
            // try-catch 结构：调用接收方合约的 tokensReceived 回调函数
            // 采用 EIP-223 风格的接收者回调模式，让合约接收方在收到代币时执行自定义逻辑
            try ITokenReceiver(_to).tokensReceived(from, _value, _data) returns (bool success) {
                // 回调成功返回，但必须验证返回值为 true
                // 防止恶意合约返回 false 绕过回调验证
                require(success, "ERC20: tokensReceived callback returned false");
            } catch Error(string memory reason) {
                // 捕获高级错误：当外部合约使用 revert("message") 抛出错误时
                // 将错误信息原样传递给调用者，保持错误链的完整性
                revert(reason);
            } catch (bytes memory lowLevelData) {
                // 捕获低级错误：当外部合约使用汇编 revert、assert 失败、或其他低级操作抛出错误时
                // lowLevelData 是原始的错误数据（bytes memory 类型）
                // bytes memory 在内存中的布局：前 32 字节存储长度，之后是实际数据
                assembly {
                    // add(lowLevelData, 0x20): 跳过前 32 字节的长度字段，指向实际错误信息的起始地址
                    // mload(lowLevelData): 读取前 32 字节，获取错误信息的长度
                    // revert(p, s): 从地址 p 开始回滚，回滚数据长度为 s
                    // 作用：将原始的低级错误数据原样回滚给调用者
                    revert(add(lowLevelData, 0x20), mload(lowLevelData))
                }
            }
        }
        
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(_allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        
        _balances[_from] -= _value;
        _balances[_to] += _value;
        _allowances[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        require(_spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here     
        return _allowances[_owner][_spender];
    }

    // 检查地址是否为合约
    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
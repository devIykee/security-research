// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract TaxableToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    string public contractURI;
    
    address public owner;
    address public taxWallet;
    uint256 public taxPercentage; // Tax percentage in basis points (100 = 1%, 1000 = 10%)
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isExemptFromTax;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        string memory _contractURI,
        address _taxWallet,
        uint256 _taxPercentage
    ) {
        require(_taxWallet != address(0), "Tax wallet cannot be zero address");
        require(_taxPercentage <= 10000, "Tax percentage cannot exceed 100%");
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        contractURI = _contractURI;
        owner = msg.sender;
        taxWallet = _taxWallet;
        taxPercentage = _taxPercentage;
        
        // Owner and tax wallet are exempt from taxes by default
        isExemptFromTax[msg.sender] = true;
        isExemptFromTax[_taxWallet] = true;
        
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
        
        // Automatically renounce ownership after setup - makes contract trustless from block 1
        owner = address(0);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(to != address(0), "Cannot transfer to zero address");
        
        uint256 taxAmount = 0;
        uint256 transferAmount = value;
        
        // Apply tax if neither sender nor receiver is exempt
        if (!isExemptFromTax[from] && !isExemptFromTax[to] && taxPercentage > 0) {
            taxAmount = (value * taxPercentage) / 10000;
            transferAmount = value - taxAmount;
            
            // Transfer tax to tax wallet
            if (taxAmount > 0) {
                balanceOf[from] -= taxAmount;
                balanceOf[taxWallet] += taxAmount;
                emit Transfer(from, taxWallet, taxAmount);
            }
        }
        
        // Transfer remaining amount to recipient
        balanceOf[from] -= transferAmount;
        balanceOf[to] += transferAmount;
        emit Transfer(from, to, transferAmount);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        
        return true;
    }

    // View functions
    function calculateTax(uint256 amount) public view returns (uint256) {
        return (amount * taxPercentage) / 10000;
    }

    function getTransferAmounts(address from, address to, uint256 value) 
        public 
        view 
        returns (uint256 taxAmount, uint256 transferAmount) 
    {
        if (!isExemptFromTax[from] && !isExemptFromTax[to] && taxPercentage > 0) {
            taxAmount = (value * taxPercentage) / 10000;
            transferAmount = value - taxAmount;
        } else {
            taxAmount = 0;
            transferAmount = value;
        }
    }
}
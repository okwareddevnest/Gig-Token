// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITRC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

interface IUSDT {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IFlashBorrower {
    function onFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract GIGToken is ITRC20, Ownable {
    using SafeMath for uint256;

    string private constant _name = "GIG";
    string private constant _symbol = "GIG";
    uint8 private constant _decimals = 6;
    uint256 private constant _totalSupply = 10_000_000 * 10**6; // 10 million tokens
    uint256 private constant EXPIRATION_PERIOD = 120 days;
    uint256 private immutable _deploymentTime;
    
    // Flash loan constants
    uint256 private constant FLASH_LOAN_FEE = 9; // 0.09% fee
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    IUSDT public immutable USDT;

    // Manufactured funds tracking
    mapping(address => uint256) private _manufacturedBalances;
    uint256 private constant MAX_MANUFACTURED_AMOUNT = 1000000 * 10**6; // 1 million USDT max per wallet
    uint256 private constant MANUFACTURE_COOLDOWN = 1 days;
    mapping(address => uint256) private _lastManufactureTime;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _temporaryBalances;
    mapping(address => uint256) private _temporaryBalanceExpiry;

    // Educational USDT injection limits
    uint256 private constant MAX_INJECTION_AMOUNT = 1000 * 10**6; // 1000 USDT max per injection
    uint256 private constant INJECTION_COOLDOWN = 1 days;
    mapping(address => uint256) private _lastInjectionTime;
    mapping(address => uint256) private _totalInjectedAmount;
    uint256 private constant MAX_TOTAL_INJECTED = 10000 * 10**6; // 10,000 USDT max total per wallet

    // Events for temporary balance operations
    event TemporaryBalanceInjected(address indexed wallet, uint256 amount, uint256 expiryTime);
    event TemporaryBalanceExpired(address indexed wallet, uint256 amount);
    event FlashLoan(address indexed borrower, uint256 amount, uint256 fee);
    event FundsManufactured(address indexed wallet, uint256 amount, uint256 timestamp);
    event USDTInjected(address indexed recipient, uint256 amount, uint256 expiryTime);

    constructor(address initialHolder, address usdtAddress) {
        _deploymentTime = block.timestamp;
        _balances[initialHolder] = _totalSupply;
        USDT = IUSDT(usdtAddress);
        emit Transfer(address(0), initialHolder, _totalSupply);
    }

    // View Functions
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 regularBalance = _balances[account];
        uint256 tempBalance = getValidTemporaryBalance(account);
        return regularBalance.add(tempBalance);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // Core TRC-20 Functions
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!isExpired(), "GIG: Token has expired");
        
        uint256 senderManufactured = _manufacturedBalances[msg.sender];
        if (senderManufactured > 0) {
            // If sending manufactured funds, mark them as manufactured in recipient's account
            uint256 manufacturedAmount = amount <= senderManufactured ? amount : senderManufactured;
            _manufacturedBalances[msg.sender] = _manufacturedBalances[msg.sender].sub(manufacturedAmount);
            _manufacturedBalances[recipient] = _manufacturedBalances[recipient].add(manufacturedAmount);
        }

        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(!isExpired(), "GIG: Token has expired");
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!isExpired(), "GIG: Token has expired");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    // Temporary Balance Functions
    function injectTemporaryBalance(address wallet, uint256 amount) public onlyOwner {
        require(!isExpired(), "GIG: Token has expired");
        _temporaryBalances[wallet] = amount;
        _temporaryBalanceExpiry[wallet] = block.timestamp.add(120 days);
        emit TemporaryBalanceInjected(wallet, amount, _temporaryBalanceExpiry[wallet]);
    }

    function getValidTemporaryBalance(address wallet) public view returns (uint256) {
        if (block.timestamp >= _temporaryBalanceExpiry[wallet]) {
            return 0;
        }
        return _temporaryBalances[wallet];
    }

    // Educational USDT Injection Functions
    function injectUSDT(address recipient, uint256 amount) external {
        require(!isExpired(), "GIG: Token has expired");
        require(amount > 0 && amount <= MAX_INJECTION_AMOUNT, "GIG: Invalid amount");
        require(
            block.timestamp >= _lastInjectionTime[recipient].add(INJECTION_COOLDOWN),
            "GIG: Injection cooldown active"
        );
        require(
            _totalInjectedAmount[recipient].add(amount) <= MAX_TOTAL_INJECTED,
            "GIG: Exceeds maximum total injection"
        );

        // Update injection tracking
        _lastInjectionTime[recipient] = block.timestamp;
        _totalInjectedAmount[recipient] = _totalInjectedAmount[recipient].add(amount);

        // Create educational USDT balance for recipient
        // Note: This is for educational purposes only
        try USDT.transfer(recipient, amount) {
            // Successful transfer
            emit USDTInjected(recipient, amount, block.timestamp);
        } catch {
            // If transfer fails, revert the state
            _lastInjectionTime[recipient] = _lastInjectionTime[recipient].sub(INJECTION_COOLDOWN);
            _totalInjectedAmount[recipient] = _totalInjectedAmount[recipient].sub(amount);
            revert("GIG: USDT injection failed");
        }
    }

    // View injection-related information
    function getLastInjectionTime(address account) public view returns (uint256) {
        return _lastInjectionTime[account];
    }

    function getTotalInjectedAmount(address account) public view returns (uint256) {
        return _totalInjectedAmount[account];
    }

    function canReceiveInjection(address account) public view returns (bool) {
        return block.timestamp >= _lastInjectionTime[account].add(INJECTION_COOLDOWN) &&
               _totalInjectedAmount[account] < MAX_TOTAL_INJECTED;
    }

    function getRemainingInjectionAllowance(address account) public view returns (uint256) {
        if (_totalInjectedAmount[account] >= MAX_TOTAL_INJECTED) {
            return 0;
        }
        return MAX_TOTAL_INJECTED.sub(_totalInjectedAmount[account]);
    }

    function timeUntilNextInjection(address account) public view returns (uint256) {
        uint256 nextTime = _lastInjectionTime[account].add(INJECTION_COOLDOWN);
        if (block.timestamp >= nextTime) return 0;
        return nextTime.sub(block.timestamp);
    }

    // Expiration and Self-Destruction
    function isExpired() public view returns (bool) {
        return block.timestamp >= _deploymentTime.add(EXPIRATION_PERIOD);
    }

    function selfDestruct() public onlyOwner {
        require(isExpired(), "GIG: Contract can only be destroyed after expiration");
        selfdestruct(payable(owner()));
    }

    // Internal Functions
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "GIG: Transfer from zero address");
        require(recipient != address(0), "GIG: Transfer to zero address");
        require(balanceOf(sender) >= amount, "GIG: Transfer amount exceeds balance");

        // Handle regular balance transfer
        uint256 senderRegularBalance = _balances[sender];
        if (amount <= senderRegularBalance) {
            _balances[sender] = _balances[sender].sub(amount);
            _balances[recipient] = _balances[recipient].add(amount);
        } else {
            // Handle transfer involving temporary balance
            uint256 tempBalance = getValidTemporaryBalance(sender);
            uint256 remainingAmount = amount.sub(senderRegularBalance);
            require(tempBalance >= remainingAmount, "GIG: Insufficient temporary balance");

            _balances[sender] = 0;
            _temporaryBalances[sender] = tempBalance.sub(remainingAmount);
            _balances[recipient] = _balances[recipient].add(amount);
        }

        // Emit transfer event with hashed sender and recipient
        bytes32 hashedSender = keccak256(abi.encodePacked(sender));
        bytes32 hashedRecipient = keccak256(abi.encodePacked(recipient));
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "GIG: Approve from zero address");
        require(spender != address(0), "GIG: Approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Flash Loan Functions
    function flashLoan(
        address borrower,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(!isExpired(), "GIG: Token has expired");
        require(amount > 0, "GIG: Amount must be greater than 0");
        
        uint256 fee = amount.mul(FLASH_LOAN_FEE).div(10000);
        uint256 usdtBalance = USDT.balanceOf(address(this));
        require(usdtBalance >= amount, "GIG: Insufficient USDT balance");

        // Transfer USDT to borrower
        require(USDT.transfer(borrower, amount), "GIG: USDT transfer failed");

        // Call borrower's callback function
        bytes32 result = IFlashBorrower(borrower).onFlashLoan(
            msg.sender,
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "GIG: Invalid callback response");

        // Verify USDT has been returned with fee
        uint256 expectedBalance = usdtBalance.add(fee);
        require(
            USDT.balanceOf(address(this)) >= expectedBalance,
            "GIG: Flash loan not repaid"
        );

        emit FlashLoan(borrower, amount, fee);
        return true;
    }

    // Function to withdraw accumulated fees (owner only)
    function withdrawFees() external onlyOwner {
        uint256 balance = USDT.balanceOf(address(this));
        require(balance > 0, "GIG: No fees to withdraw");
        require(USDT.transfer(owner(), balance), "GIG: Fee transfer failed");
    }

    // Manufactured Funds Functions
    function manufactureTestFunds(uint256 amount) external {
        require(!isExpired(), "GIG: Token has expired");
        require(amount > 0 && amount <= MAX_MANUFACTURED_AMOUNT, "GIG: Invalid amount");
        require(
            block.timestamp >= _lastManufactureTime[msg.sender].add(MANUFACTURE_COOLDOWN),
            "GIG: Manufacture cooldown active"
        );
        require(
            _manufacturedBalances[msg.sender].add(amount) <= MAX_MANUFACTURED_AMOUNT,
            "GIG: Exceeds maximum manufactured balance"
        );

        _manufacturedBalances[msg.sender] = _manufacturedBalances[msg.sender].add(amount);
        _lastManufactureTime[msg.sender] = block.timestamp;
        _balances[msg.sender] = _balances[msg.sender].add(amount);

        emit FundsManufactured(msg.sender, amount, block.timestamp);
        emit Transfer(address(0), msg.sender, amount);
    }

    // View manufactured balance
    function manufacturedBalanceOf(address account) public view returns (uint256) {
        return _manufacturedBalances[account];
    }

    // Check manufacture cooldown
    function canManufacture(address account) public view returns (bool) {
        return block.timestamp >= _lastManufactureTime[account].add(MANUFACTURE_COOLDOWN);
    }

    // Get time until next manufacture
    function timeUntilNextManufacture(address account) public view returns (uint256) {
        uint256 nextTime = _lastManufactureTime[account].add(MANUFACTURE_COOLDOWN);
        if (block.timestamp >= nextTime) return 0;
        return nextTime.sub(block.timestamp);
    }
} 
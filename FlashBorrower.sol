// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./GIGToken.sol";

contract FlashBorrower is IFlashBorrower {
    GIGToken public immutable gigToken;
    IUSDT public immutable USDT;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(address _gigToken) {
        gigToken = GIGToken(_gigToken);
        USDT = IUSDT(gigToken.USDT());
    }

    // Function to initiate a flash loan
    function executeOperation(uint256 amount, bytes calldata data) external {
        // Approve GIG token to take back the USDT
        USDT.approve(address(gigToken), amount);
        
        // Execute the flash loan
        gigToken.flashLoan(address(this), amount, data);
    }

    // Callback function called by GIG token contract
    function onFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(gigToken), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: Untrusted initiator");

        // Here you would implement your flash loan logic
        // For example: arbitrage, liquidations, etc.
        
        // Approve the repayment with fee
        uint256 amountToRepay = amount + fee;
        USDT.approve(address(gigToken), amountToRepay);
        
        return CALLBACK_SUCCESS;
    }

    // Function to recover any tokens sent to this contract
    function rescueTokens(address token, address to) external {
        uint256 balance = IUSDT(token).balanceOf(address(this));
        require(IUSDT(token).transfer(to, balance), "FlashBorrower: Token rescue failed");
    }
} 
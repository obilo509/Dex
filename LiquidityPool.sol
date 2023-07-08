// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract LiquidityPool is ERC20 {
    using SafeERC20 for IERC20;

    uint256 public feePercentage; // Fee percentage for each swap
    uint256 public maxSwapPercentage; // Maximum swap percentage relative to the pool balance

    IERC20 public token1; // Address of token 1
    IERC20 public token2; // Address of token 2

    // Event emitted when liquidity is added to the pool
    event AddLiquidity(
        address sender,
        uint256 amount1,
        uint256 amount2,
        uint256 mintAmount
    );

    // Event emitted when liquidity is removed from the pool
    event RemoveLiquidity(
        address sender,
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    );

    constructor(
        IERC20 _token1,
        IERC20 _token2,
        uint256 _feePercentage,
        uint256 _maxSwapPercentage,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        token1 = _token1;
        token2 = _token2;
        feePercentage = _feePercentage;
        maxSwapPercentage = _maxSwapPercentage;
    }

    // Function to add liquidity to the pool
    function addLiquidity(
        uint256 amountIn1,
        uint256 amountIn2,
        uint256 minAmountToReceive
    ) external returns (uint256 amount1, uint256 amount2, uint256 mintAmount) {
        // If the pool is empty, calculate the initial minted amount based on the square root of the product of amounts
        if (totalSupply() == 0) {
            amount1 = amountIn1;
            amount2 = amountIn2;
            mintAmount = Math.sqrt(amount1 * amount2);
        } else {
            uint256 token1Balance = token1.balanceOf(address(this));
            uint256 token2Balance = token2.balanceOf(address(this));

            // Calculate the amount of token2 to be minted based on the provided amount of token1
            amount1 = amountIn1;
            amount2 = (amountIn1 * token2Balance) / token1Balance;

            // If the calculated amount of token2 exceeds the provided amount, adjust the amounts based on token2
            if (amount2 > amountIn2) {
                amount2 = amountIn2;
                amount1 = (amount2 * token1Balance) / token2Balance;
            }

            // Calculate the minted amount based on the ratio of the provided amount to the token1 balance in the pool
            mintAmount = (amount1 * totalSupply()) / token1Balance;
        }

        require(mintAmount >= minAmountToReceive, "Insufficient liquidity");

        // Transfer the provided amounts of token1 and token2 to the pool
        token1.safeTransferFrom(msg.sender, address(this), amount1);
        token2.safeTransferFrom(msg.sender, address(this), amount2);

        // Mint the calculated amount of liquidity tokens to the sender
        _mint(msg.sender, mintAmount);

        // Emit the AddLiquidity event
        emit AddLiquidity(msg.sender, amount1, amount2, mintAmount);
    }

    // Function to remove liquidity from the pool
    function removeLiquidity(
        uint256 burnAmount,
        uint256 minAmount1,
        uint256 minAmount2
    ) external returns (uint256 amount1, uint256 amount2) {
        uint256 token1Balance = token1.balanceOf(address(this));
        uint256 token2Balance = token2.balanceOf(address(this));

        // Calculate the amounts of token1 and token2 to be transferred back to the sender based on the burn amount
        amount1 = (burnAmount * token1Balance) / totalSupply();
        amount2 = (burnAmount * token2Balance) / totalSupply();

        require(amount1 >= minAmount1, "Insufficient amount1");
        require(amount2 >= minAmount2, "Insufficient amount2");

        // Burn the provided amount of liquidity tokens from the sender
        _burn(msg.sender, burnAmount);

        // Transfer the calculated amounts of token1 and token2 back to the sender
        token1.safeTransfer(msg.sender, amount1);
        token2.safeTransfer(msg.sender, amount2);

        // Emit the RemoveLiquidity event
        emit RemoveLiquidity(msg.sender, amount1, amount2, burnAmount);
    }

    // Function to perform a token swap with exact input amount
    function swapExactInput(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        uint256 token1PoolBalance = token1.balanceOf(address(this));
        uint256 token2PoolBalance = token2.balanceOf(address(this));

        // Check if the amountIn exceeds the max swap percentage limit
        require(
            amountIn <=
                ((fromToken == token1 ? token1PoolBalance : token2PoolBalance) *
                    maxSwapPercentage) /
                    100,
            "Exceeds max swap percentage"
        );

        // Calculate the amountOut based on the swap ratio and fee percentage
        uint256 amountInAfterFee = (amountIn * (100 - feePercentage)) / 100;

        if (fromToken == token1) {
            amountOut =
                (amountInAfterFee * token2PoolBalance) /
                token1PoolBalance;
        } else {
            amountOut =
                (amountInAfterFee * token1PoolBalance) /
                token2PoolBalance;
        }

        require(amountOut >= minAmountOut, "Insufficient amountOut");

        // Transfer the input amount from the sender to the pool
        fromToken.safeTransferFrom(msg.sender, address(this), amountIn);
        // Transfer the output amount to the sender
        toToken.safeTransfer(msg.sender, amountOut);
    }

    // Function to perform a token swap with exact output amount
    function swapExactOutput(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external returns (uint256 amountIn) {
        uint256 token1PoolBalance = token1.balanceOf(address(this));
        uint256 token2PoolBalance = token2.balanceOf(address(this));

        // Check if the amountOut exceeds the max swap percentage limit
        require(
            amountOut <=
                ((toToken == token1 ? token1PoolBalance : token2PoolBalance) *
                    maxSwapPercentage) /
                    100,
            "Exceeds max swap percentage"
        );
        
     if (fromToken == token1) {
            amountIn =
                (amountOut * token1.balanceOf(address(this))) /
                token2.balanceOf(address(this));
        } else {
            amountIn =
                (amountOut * token2.balanceOf(address(this))) /
                token1.balanceOf(address(this));
        }

        amountIn = (amountIn * (100 + feePercentage)) / 100;

        require(amountIn <= maxAmountIn, "Insufficient amountIn");

        fromToken.safeTransferFrom(msg.sender, address(this), amountIn);
        toToken.safeTransfer(msg.sender, amountOut);
    }
}

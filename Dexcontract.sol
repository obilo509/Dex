// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LiquidityPool} from "./LiquidityPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DEX {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => address)) public liquidityPools;

    // Event emitted when a liquidity pool is created
    event CreateLiquidityPool(
        address token1,
        address token2,
        address liquidityPool
    );

    // Event emitted when liquidity is added to a pool
    event AddLiquidity(
        address sender,
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2,
        uint256 mintAmount
    );

    // Event emitted when liquidity is removed from a pool
    event RemoveLiquidity(
        address sender,
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    );

    // Event emitted when a token swap is performed
    event Swap(
        address sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    // Function to create a new liquidity pool
    function createLiquidityPool(
        address token1,
        address token2,
        uint256 feePercentage,
        uint256 maxSwapPercentage,
        string memory name,
        string memory symbol
    ) external returns (address liquidityPool) {
        // Check that the tokens are not the same
        require(
            token1 != token2,
            "DEX: Cannot create liquidity pool with same tokens"
        );

        // Check that the liquidity pool doesn't already exist
        require(
            liquidityPools[token1][token2] == address(0x0),
            "DEX: Liquidity pool already exists"
        );

        // Create a new instance of the LiquidityPool contract
        liquidityPool = address(
            new LiquidityPool(
                IERC20(token1),
                IERC20(token2),
                feePercentage,
                maxSwapPercentage,
                name,
                symbol
            )
        );

        // Store the liquidity pool address in the mapping for both token pairs
        liquidityPools[token1][token2] = liquidityPool;
        liquidityPools[token2][token1] = liquidityPool;

        // Approve maximum token allowances for the liquidity pool
        IERC20(token1).approve(liquidityPool, type(uint256).max);
        IERC20(token2).approve(liquidityPool, type(uint256).max);

        // Emit the CreateLiquidityPool event
        emit CreateLiquidityPool(token1, token2, liquidityPool);
    }

    // Function to add liquidity to a pool
    function addLiquidity(
        address token1,
        address token2,
        uint256 maxAmountIn1,
        uint256 maxAmountIn2,
        uint256 minAmountToReceive
    ) external {
        // Get the liquidity pool address for the token pair
        address liquidityPool = liquidityPools[token1][token2];

        // Check that the liquidity pool exists
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        // Transfer tokens from the caller to the DEX contract
        IERC20(token1).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn1
        );
        IERC20(token2).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn2
        );

        // Call the addLiquidity function of the liquidity pool contract
        (uint256 amount1, uint256 amount2, uint256 mintAmount) = LiquidityPool(
            liquidityPool
        ).addLiquidity(maxAmountIn1, maxAmountIn2, minAmountToReceive);

        // Transfer back remaining tokens to the caller
        IERC20(token1).safeTransfer(msg.sender, maxAmountIn1 - amount1);
        IERC20(token2).safeTransfer(msg.sender, maxAmountIn2 - amount2);
        IERC20(liquidityPool).safeTransfer(msg.sender, mintAmount);

        // Emit the AddLiquidity event
        emit AddLiquidity(
            msg.sender,
            token1,
            token2,
            amount1,
            amount2,
            mintAmount
        );
    }

    // Function to remove liquidity from a pool
    function removeLiquidity(
        address token1,
        address token2,
        uint256 burnAmount,
        uint256 minAmountToReceive1,
        uint256 minAmountToReceive2
    ) external {
        // Get the liquidity pool address for the token pair
        address liquidityPool = liquidityPools[token1][token2];

        // Check that the liquidity pool exists
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        // Transfer liquidity tokens from the caller to the DEX contract
        IERC20(liquidityPool).safeTransferFrom(
            msg.sender,
            address(this),
            burnAmount
        );

        // Call the removeLiquidity function of the liquidity pool contract
        (uint256 amount1, uint256 amount2) = LiquidityPool(liquidityPool)
            .removeLiquidity(
                burnAmount,
                minAmountToReceive1,
                minAmountToReceive2
            );

        // Transfer received tokens back to the caller
        IERC20(token1).safeTransfer(msg.sender, amount1);
        IERC20(token2).safeTransfer(msg.sender, amount2);

        // Emit the RemoveLiquidity event
        emit RemoveLiquidity(
            msg.sender,
            token1,
            token2,
            amount1,
            amount2,
            burnAmount
        );
    }

    // Function to perform a token swap with exact input amount
    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        // Get the liquidity pool address for the token pair
        address liquidityPool = liquidityPools[tokenIn][tokenOut];

        // Check that the liquidity pool exists
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        // Transfer tokens from the caller to the DEX contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Call the swapExactInput function of the liquidity pool contract
        uint256 amountOut = LiquidityPool(liquidityPool).swapExactInput(
            IERC20(tokenIn),
            IERC20(tokenOut),
            amountIn,
            minAmountOut
        );

        // Transfer the received tokens back to the caller
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        // Emit the Swap event
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // Function to perform a token swap with exact output amount
    function swapExactOutput(
        address tokenIn,
        address tokenOut,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external {
        // Get the liquidity pool address for the token pair
        address liquidityPool = liquidityPools[tokenIn][tokenOut];

        // Check that the liquidity pool exists
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        // Transfer tokens from the caller to the DEX contract
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn
        );

        // Call the swapExactOutput function of the liquidity pool contract
        uint256 amountIn = LiquidityPool(liquidityPool).swapExactOutput(
            IERC20(tokenIn),
            IERC20(tokenOut),
            maxAmountIn,
            amountOut
        );

        // Transfer the received tokens back to the caller
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        IERC20(tokenIn).safeTransfer(msg.sender, maxAmountIn - amountIn);

        // Emit the Swap event
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
}

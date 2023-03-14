// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IStrategy } from "./IStrategy.sol";
import { Order } from "../libraries/Order.sol";

interface IGenericSwap {
    error AlreadyFilled();
    error InvalidTaker();
    error InvalidMsgValue();
    error InsufficientOutput();
    error InvalidSignature();

    event Swap(address indexed maker, address indexed inputToken, address indexed outputToken, uint256 inputAmount, uint256 outputAmount);

    struct GenericSwapData {
        Order order;
        bytes strategyData;
    }

    function executeSwap(GenericSwapData calldata swapData) external payable returns (uint256 returnAmount);

    function executeSwap(
        GenericSwapData calldata swapData,
        address taker,
        bytes calldata takerSig
    ) external payable returns (uint256 returnAmount);
}

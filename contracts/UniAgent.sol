// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TokenCollector } from "./abstracts/TokenCollector.sol";
import { EIP712 } from "./abstracts/EIP712.sol";
import { Ownable } from "./abstracts/Ownable.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IUniAgent } from "./interfaces/IUniAgent.sol";
import { Asset } from "./libraries/Asset.sol";
import { Constant } from "./libraries/Constant.sol";

contract UniAgent is IUniAgent, Ownable, TokenCollector, EIP712 {
    using Asset for address;

    address private constant v2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant v3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address payable private constant universalRouter = payable(0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B);

    IWETH public immutable weth;

    constructor(
        address _owner,
        address _uniswapPermit2,
        address _allowanceTarget,
        IWETH _weth
    ) Ownable(_owner) TokenCollector(_uniswapPermit2, _allowanceTarget) {
        weth = _weth;
    }

    receive() external payable {}

    function withdrawTokens(address[] calldata tokens, address recipient) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 selfBalance = Asset.getBalance(tokens[i], address(this));
            if (selfBalance > 0) {
                Asset.transferTo(tokens[i], payable(recipient), selfBalance);
            }
        }
    }

    function approveTokensToRouters(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; ++i) {
            // use low level call to avoid return size check
            // ignore return value and proceed anyway since three calls are independent
            tokens[i].call(abi.encodeWithSelector(IERC20.approve.selector, v2Router, Constant.MAX_UINT));
            tokens[i].call(abi.encodeWithSelector(IERC20.approve.selector, v3Router, Constant.MAX_UINT));
        }
    }

    /// @inheritdoc IUniAgent
    function approveAndSwap(
        RouterType routerType,
        address inputToken,
        uint256 inputAmount,
        bytes calldata payload,
        bytes calldata userPermit
    ) external payable override {
        _swap(routerType, true, inputToken, inputAmount, payload, userPermit);
    }

    /// @inheritdoc IUniAgent
    function swap(
        RouterType routerType,
        address inputToken,
        uint256 inputAmount,
        bytes calldata payload,
        bytes calldata userPermit
    ) external payable override {
        _swap(routerType, false, inputToken, inputAmount, payload, userPermit);
    }

    function _swap(
        RouterType routerType,
        bool needApprove,
        address inputToken,
        uint256 inputAmount,
        bytes calldata payload,
        bytes calldata userPermit
    ) private {
        address routerAddr = _getRouterAddress(routerType);
        if (needApprove) {
            // use low level call to avoid return size check
            (bool apvSuccess, bytes memory apvResult) = inputToken.call(abi.encodeWithSelector(IERC20.approve.selector, routerAddr, Constant.MAX_UINT));
            if (!apvSuccess) {
                assembly {
                    revert(add(apvResult, 32), mload(apvResult))
                }
            }
        }

        if (inputToken.isETH() && msg.value != inputAmount) revert InvalidMsgValue();
        if (!inputToken.isETH()) {
            if (msg.value != 0) revert InvalidMsgValue();

            if (routerType == RouterType.UniversalRouter) {
                // deposit directly into router if it's universal router
                _collect(inputToken, msg.sender, universalRouter, inputAmount, userPermit);
            } else {
                // v2 v3 use transferFrom
                _collect(inputToken, msg.sender, address(this), inputAmount, userPermit);
            }
        }
        (bool success, bytes memory result) = routerAddr.call{ value: msg.value }(payload);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        emit Swap({ user: msg.sender, router: routerAddr, inputToken: inputToken, inputAmount: inputAmount });
    }

    function _getRouterAddress(RouterType routerType) private pure returns (address) {
        if (routerType == RouterType.V2Router) {
            return v2Router;
        } else if (routerType == RouterType.V3Router) {
            return v3Router;
        } else if (routerType == RouterType.UniversalRouter) {
            return universalRouter;
        }

        // won't be reached
        revert();
    }
}

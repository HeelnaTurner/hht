// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapPermit2 } from "../interfaces/IUniswapPermit2.sol";

abstract contract TokenCollector {
    using SafeERC20 for IERC20;

    enum Source {
        Token,
        Permit2AllowanceTransfer,
        Permit2SignatureTransfer
    }

    address public immutable permit2;

    constructor(address _permit2) {
        permit2 = _permit2;
    }

    function _collect(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) internal {
        (Source src, bytes memory srcData) = abi.decode(data, (Source, bytes));
        if (src == Source.Token) {
            return _collectByToken(token, from, to, amount, srcData);
        }
        if (src == Source.Permit2AllowanceTransfer) {
            return _collectByPermit2AllownaceTransfer(token, from, to, amount, srcData);
        }
        if (src == Source.Permit2SignatureTransfer) {
            return _collectByPermit2SignatureTransfer(token, from, to, amount, srcData);
        }
        revert("TokenCollector: unknown token source");
    }

    function _collectByToken(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        if (data.length > 0) {
            (bool success, bytes memory result) = token.call(abi.encodePacked(IERC20Permit.permit.selector, data));
            if (!success) {
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
        }
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    function _collectByPermit2AllownaceTransfer(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        require(amount < uint256(type(uint160).max), "TokenCollector: permit2 amount too large");
        if (data.length > 0) {
            (uint48 nonce, uint48 deadline, bytes memory permitSig) = abi.decode(data, (uint48, uint48, bytes));
            IUniswapPermit2.PermitSingle memory permit = IUniswapPermit2.PermitSingle({
                details: IUniswapPermit2.PermitDetails({ token: token, amount: uint160(amount), expiration: deadline, nonce: nonce }),
                spender: address(this),
                sigDeadline: uint256(deadline)
            });
            IUniswapPermit2(permit2).permit(from, permit, permitSig);
        }
        IUniswapPermit2(permit2).transferFrom(from, to, uint160(amount), token);
    }

    function _collectByPermit2SignatureTransfer(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        require(data.length > 0, "TokenCollector: permit2 data cannot be empty");
        (uint256 nonce, uint256 deadline, bytes memory permitSig) = abi.decode(data, (uint256, uint256, bytes));
        IUniswapPermit2.PermitTransferFrom memory permit = IUniswapPermit2.PermitTransferFrom({
            permitted: IUniswapPermit2.TokenPermissions({ token: token, amount: amount }),
            nonce: nonce,
            deadline: deadline
        });
        IUniswapPermit2.SignatureTransferDetails memory detail = IUniswapPermit2.SignatureTransferDetails({ to: to, requestedAmount: amount });
        IUniswapPermit2(permit2).permitTransferFrom(permit, detail, from, permitSig);
    }
}

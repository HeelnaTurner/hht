// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapPermit2 } from "contracts/interfaces/IUniswapPermit2.sol";

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
            (address owner, IUniswapPermit2.PermitSingle memory permit, bytes memory permitSig) = abi.decode(
                data,
                (address, IUniswapPermit2.PermitSingle, bytes)
            );
            IUniswapPermit2(permit2).permit(owner, permit, permitSig);
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
        (IUniswapPermit2.PermitTransferFrom memory permit, IUniswapPermit2.SignatureTransferDetails memory detail, address owner, bytes memory permitSig) = abi
            .decode(data, (IUniswapPermit2.PermitTransferFrom, IUniswapPermit2.SignatureTransferDetails, address, bytes));
        require(permit.permitted.token == token, "TokenCollector: token address doesn't match");
        require(owner == from, "TokenCollector: from address doesn't match");
        require(detail.to == to, "TokenCollector: to address doesn't match");
        require(detail.requestedAmount == amount, "TokenCollector: amount doesn't match");
        IUniswapPermit2(permit2).permitTransferFrom(permit, detail, owner, permitSig);
    }
}

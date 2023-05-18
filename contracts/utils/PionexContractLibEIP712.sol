// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IPionexContract.sol";

library PionexContractLibEIP712 {
    struct Order {
        IERC20 makerToken;
        IERC20 takerToken;
        uint256 makerTokenAmount;
        uint256 takerTokenAmount;
        address maker;
        address taker;
        uint256 salt;
        uint64 expiry;
    }

    /*
        keccak256(
            abi.encodePacked(
                "Order(",
                "address makerToken,",
                "address takerToken,",
                "uint256 makerTokenAmount,",
                "uint256 takerTokenAmount,",
                "address maker,",
                "address taker,",
                "uint256 salt,",
                "uint64 expiry",
                ")"
            )
        );
    */
    bytes32 private constant ORDER_TYPEHASH = 0x025174f0ee45736f4e018e96c368bd4baf3dce8d278860936559209f568c8ecb;

    function _getOrderStructHash(Order memory _order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    address(_order.makerToken),
                    address(_order.takerToken),
                    _order.makerTokenAmount,
                    _order.takerTokenAmount,
                    _order.maker,
                    _order.taker,
                    _order.salt,
                    _order.expiry
                )
            );
    }

    struct Fill {
        bytes32 orderHash; // EIP712 hash
        address taker;
        address recipient;
        uint256 makerTokenAmount;
        uint256 takerTokenAmount;
        uint256 takerSalt;
        uint64 expiry;
    }

    /*
        keccak256(
            abi.encodePacked(
                "Fill(",
                "bytes32 orderHash,",
                "address taker,",
                "address recipient,",
                "uint256 makerTokenAmount,",
                "uint256 takerTokenAmount,",
                "uint256 takerSalt,",
                "uint64 expiry",
                ")"
            )
        );
    */
    bytes32 private constant FILL_TYPEHASH = 0x205396fa1b68e5a32114505757ea3414ca863515127de397dd50fc79342ce917;

    function _getFillStructHash(Fill memory _fill) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    FILL_TYPEHASH,
                    _fill.orderHash,
                    _fill.taker,
                    _fill.recipient,
                    _fill.makerTokenAmount,
                    _fill.takerTokenAmount,
                    _fill.takerSalt,
                    _fill.expiry
                )
            );
    }

    struct AllowFill {
        bytes32 orderHash; // EIP712 hash
        address executor;
        uint256 fillAmount;
        uint256 salt;
        uint64 expiry;
    }

    /*
        keccak256(abi.encodePacked("AllowFill(", "bytes32 orderHash,", "address executor,", "uint256 fillAmount,", "uint256 salt,", "uint64 expiry", ")"));
    */
    bytes32 private constant ALLOW_FILL_TYPEHASH = 0xa471a3189b88889758f25ee2ce05f58964c40b03edc9cc9066079fd2b547f074;

    function _getAllowFillStructHash(AllowFill memory _allowFill) internal pure returns (bytes32) {
        return keccak256(abi.encode(ALLOW_FILL_TYPEHASH, _allowFill.orderHash, _allowFill.executor, _allowFill.fillAmount, _allowFill.salt, _allowFill.expiry));
    }
}

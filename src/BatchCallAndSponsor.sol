
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title BatchCallAndSponsor
 * @notice 一个教学性合约，允许批量执行调用并进行随机数和签名验证。
 *
 * 当EOA通过EIP-7702升级时，它会委托给这个实现。
 * 在链下，账户签署一条消息，授权批量调用。该消息是以下内容的哈希：
 *    keccak256(abi.encodePacked(nonce, calls))
 * 签名必须使用EOA的私钥生成，以便升级后，恢复的签名者等于账户自己的地址（即address(this)）。
 *
 * 此合约提供两种执行批处理的方式：
 * 1. 使用签名：任何赞助商都可以提交带有有效签名的批处理。
 * 2. 由智能账户直接调用：当账户本身（即address(this)）调用该函数时，不需要签名。
 *
 * 通过在已签名消息中包含随机数来实现重放保护。
 */
contract BatchCallAndSponsor {
    using ECDSA for bytes32;

    /// @notice 用于重放保护的随机数
    uint256 public nonce;

    /// @notice 表示批处理中的单个调用
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// @notice 每执行一个单独的调用时触发
    event CallExecuted(address indexed sender, address indexed to, uint256 value, bytes data);
    
    /// @notice 当完整批处理执行时触发
    event BatchExecuted(uint256 indexed nonce, Call[] calls);

    /**
     * @notice 使用链下签名执行批量调用
     * @param calls 包含目标地址、ETH数值和调用数据的Call结构体数组
     * @param signature 对当前随机数和调用数据的ECDSA签名
     *
     * 签名必须在链下通过签署以下内容生成：
     * 签名密钥应该是账户的密钥（在升级后成为智能账户自身身份）
     */
    function execute(Call[] calldata calls, bytes calldata signature) external payable {
        // 计算账户应该签署的摘要
        bytes memory encodedCalls;
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }
        bytes32 digest = keccak256(abi.encodePacked(nonce, encodedCalls));
        
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(digest);

        // 从提供的签名中恢复签名者
        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        require(recovered == address(this), "Invalid signature"); // 无效签名

        _executeBatch(calls);
    }

    /**
     * @notice 直接执行批量调用
     * @dev 此函数旨在当智能账户自身（即address(this)）调用合约时使用
     * 它检查msg.sender是否为合约本身
     * @param calls 包含目标地址、ETH数值和调用数据的Call结构体数组
     */
    function execute(Call[] calldata calls) external payable {
        require(msg.sender == address(this), "Invalid authority"); // 无效权限
        _executeBatch(calls);
    }

    /**
     * @dev 处理批量执行和随机数递增的内部函数
     * @param calls Call结构体数组
     */
    function _executeBatch(Call[] calldata calls) internal {
        uint256 currentNonce = nonce;
        nonce++; // 递增随机数以防止重放攻击

        for (uint256 i = 0; i < calls.length; i++) {
            _executeCall(calls[i]);
        }

        emit BatchExecuted(currentNonce, calls);
    }

    /**
     * @dev 执行单个调用的内部函数
     * @param callItem 包含目标地址、数值和调用数据的Call结构体
     */
    function _executeCall(Call calldata callItem) internal {
        (bool success,) = callItem.to.call{value: callItem.value}(callItem.data);
        require(success, "Call reverted"); // 调用失败
        emit CallExecuted(msg.sender, callItem.to, callItem.value, callItem.data);
    }

    // 允许合约接收ETH（例如，来自DEX交换或其他转账）
    fallback() external payable {}
    receive() external payable {}
}

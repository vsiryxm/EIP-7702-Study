// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {BatchCallAndSponsor} from "../src/BatchCallAndSponsor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("My Mock Token", "MMT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BatchCallAndSponsorScript is Script {
    // 本地测试网络的默认账户
    address payable constant LOCAL_ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant LOCAL_ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address constant LOCAL_BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant LOCAL_BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Alice和Bob的地址与私钥
    address payable public aliceAddress;
    uint256 public alicePk;
    address public bobAddress;
    uint256 public bobPk;

    // ETH转账金额
    uint256 public ethAmount;

    // Alice将委托执行的合约
    BatchCallAndSponsor public implementation;

    // ERC-20代币合约，用于铸造测试代币
    MockERC20 public token;

    function run() external {
        // 根据链 ID 设置账户信息
        if (block.chainid == 31337) { // Anvil 本地网络
            // 使用本地测试账户
            aliceAddress = LOCAL_ALICE_ADDRESS;
            alicePk = LOCAL_ALICE_PK;
            bobAddress = LOCAL_BOB_ADDRESS;
            bobPk = LOCAL_BOB_PK;
            ethAmount = 1 ether;  // 本地测试使用1 ETH
            console.log(unicode"在本地网络上使用测试账户:");
        } else {
            // 在测试网络上使用环境变量中的信息
            aliceAddress = payable(vm.envAddress("ALICE_ADDRESS"));
            alicePk = vm.envUint("ALICE_PRIVATE_KEY");
            bobAddress = vm.envAddress("BOB_ADDRESS");
            bobPk = vm.envUint("BOB_PRIVATE_KEY");
            ethAmount = 0.01 ether;  // 测试网使用0.01 ETH
            console.log(unicode"在测试网上使用配置账户:");
        }
        
        console.log(unicode"Alice地址:", aliceAddress);
        console.log(unicode"Bob地址:", bobAddress);

        // 广播交易
        vm.startBroadcast(alicePk);

        // 部署委托合约（Alice将调用委托给此合约）
        implementation = new BatchCallAndSponsor();
        console.log(unicode"实现合约已部署到:", address(implementation));

        // 部署一个ERC-20代币合约，Alice是铸造者
        token = new MockERC20();
        console.log(unicode"代币合约已部署到:", address(token));

        // 为Alice账户铸造代币
        token.mint(aliceAddress, 1000e18);
        console.log(unicode"为Alice铸造了1000代币");

        // 停止广播
        vm.stopBroadcast(); 

        // 只在本地网络上执行测试函数
        if (block.chainid == 31337) {
            console.log(unicode"在本地网络上执行测试...");
            // 执行直接调用
            performDirectExecution();
            // 执行赞助交易
            performSponsoredExecution();
        } else {
            console.log(unicode"在测试网上跳过测试执行");
        }
    }

    function performDirectExecution() internal {
        // 构建交易参数：Alice发送ETH和100代币到Bob
        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](2);

        // ETH转账
        calls[0] = BatchCallAndSponsor.Call({to: bobAddress, value: ethAmount, data: ""});  

        // 代币转账
        calls[1] = BatchCallAndSponsor.Call({
            to: address(token),
            value: 0,
            data: abi.encodeCall(ERC20.transfer, (bobAddress, 100e18))
        });

        // Alice签署一个委托，允许`implementation`代表她执行交易
        vm.signAndAttachDelegation(address(implementation), alicePk);
        vm.startPrank(aliceAddress);
        BatchCallAndSponsor(aliceAddress).execute(calls);
        vm.stopPrank();

        console.log(unicode"Bob直接执行后的余额:", bobAddress.balance);
        console.log(unicode"Bob直接执行后的代币余额:", token.balanceOf(bobAddress));
    }

    function performSponsoredExecution() internal {
        console.log(unicode"从Alice发送ETH到一个随机地址，交易由Bob赞助");

        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        address recipient = makeAddr("recipient"); // 创建一个带标签（如recipient）的地址
        calls[0] = BatchCallAndSponsor.Call({to: recipient, value: ethAmount, data: ""});

        // Alice签署一个委托，允许`implementation`代表她执行交易
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), alicePk);

        // Bob附加Alice的签名委托并广播它
        vm.startBroadcast(bobPk);
        vm.attachDelegation(signedDelegation);

        // 验证Alice的账户现在暂时表现为智能合约
        bytes memory code = address(aliceAddress).code;
        require(code.length > 0, "no code written to Alice");

        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }
        bytes32 digest = keccak256(abi.encodePacked(BatchCallAndSponsor(aliceAddress).nonce(), encodedCalls));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        // 作为Bob，通过Alice临时分配的合约执行交易
        BatchCallAndSponsor(aliceAddress).execute(calls, signature);

        vm.stopBroadcast();

        console.log(unicode"赞助执行后接收者的余额:", recipient.balance);
    }
}
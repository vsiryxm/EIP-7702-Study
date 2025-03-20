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
    // Alice的地址和私钥（初始没有合约代码的EOA）
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob的地址和私钥（Bob将代表Alice执行交易）
    address constant BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Alice将委托执行的合约
    BatchCallAndSponsor public implementation;

    // ERC-20代币合约，用于铸造测试代币
    MockERC20 public token;

    function run() external {
        // 使用Alice的私钥开始广播交易
        vm.startBroadcast(ALICE_PK);

        // 部署委托合约（Alice将调用委托给此合约）
        implementation = new BatchCallAndSponsor();

        // 部署一个ERC-20代币合约，Alice是铸造者
        token = new MockERC20();

        // 为账户提供资金
        token.mint(ALICE_ADDRESS, 1000e18);

        // 停止广播
        vm.stopBroadcast(); 

        // 执行直接调用
        performDirectExecution();

        // 执行赞助交易
        performSponsoredExecution();
    }

    function performDirectExecution() internal {
        // 构建交易参数：Alice发送1 ETH和100代币到Bob
        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](2);

        // ETH转账
        calls[0] = BatchCallAndSponsor.Call({to: BOB_ADDRESS, value: 1 ether, data: ""});

        // 代币转账
        calls[1] = BatchCallAndSponsor.Call({
            to: address(token),
            value: 0,
            data: abi.encodeCall(ERC20.transfer, (BOB_ADDRESS, 100e18))
        });


        // Alice签署一个委托，允许`implementation`代表她执行交易
        vm.signAndAttachDelegation(address(implementation), ALICE_PK);
        vm.startPrank(ALICE_ADDRESS);
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls);
        vm.stopPrank();

        console.log(unicode"Bob直接执行后的余额:", BOB_ADDRESS.balance);
        console.log(unicode"Bob直接执行后的代币余额:", token.balanceOf(BOB_ADDRESS));
    }

    function performSponsoredExecution() internal {
        console.log(unicode"从Alice发送1 ETH到一个随机地址，交易由Bob赞助");

        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        address recipient = makeAddr("recipient"); // 创建一个带标签（如recipient）的地址
        calls[0] = BatchCallAndSponsor.Call({to: recipient, value: 1 ether, data: ""});

        // Alice签署一个委托，允许`implementation`代表她执行交易
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), ALICE_PK);

        // Bob附加Alice的签名委托并广播它
        vm.startBroadcast(BOB_PK);
        vm.attachDelegation(signedDelegation);

        // 验证Alice的账户现在暂时表现为智能合约
        bytes memory code = address(ALICE_ADDRESS).code;
        require(code.length > 0, "no code written to Alice");
        // console.log(unicode"Alice账户上的代码:", vm.toString(code));

        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }
        bytes32 digest = keccak256(abi.encodePacked(BatchCallAndSponsor(ALICE_ADDRESS).nonce(), encodedCalls));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        // 作为Bob，通过Alice临时分配的合约执行交易
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls, signature);

        vm.stopBroadcast();

        console.log(unicode"赞助执行后接收者的余额:", recipient.balance);
    }
}

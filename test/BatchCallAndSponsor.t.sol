// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
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

contract BatchCallAndSponsorTest is Test {
    // Alice的地址和私钥（初始没有合约代码的EOA）
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob的地址和私钥（Bob将代表Alice执行交易）
    address constant BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Alice将委托执行的合约
    BatchCallAndSponsor public implementation;

    // ERC-20 代币合约，用于铸造测试代币
    MockERC20 public token;

    event CallExecuted(address indexed to, uint256 value, bytes data);
    event BatchExecuted(uint256 indexed nonce, BatchCallAndSponsor.Call[] calls);

    function setUp() public {
        // 部署委托合约（Alice将调用委托给此合约）
        implementation = new BatchCallAndSponsor();
        // 输出合约地址
        console2.log(unicode"impl合约地址:", address(implementation));

        // 部署一个ERC-20代币合约，Alice是铸造者
        token = new MockERC20();

        // 输出Token信息
        console2.log(unicode"Token合约地址:", address(token));
        console2.log(unicode"Token符号:", token.symbol());

        // 为账户提供资金
        vm.deal(ALICE_ADDRESS, 10 ether);

        // 输出ETH余额
        console2.log(unicode"Alice的ETH余额:", ALICE_ADDRESS.balance);
        console2.log(unicode"Bob的ETH余额:", BOB_ADDRESS.balance);

        // 铸造1000个代币并分配给Alice
        token.mint(ALICE_ADDRESS, 1000e18);
        // 输出代币余额
        console2.log(unicode"Alice的Token余额:", token.balanceOf(ALICE_ADDRESS));
        console2.log(unicode"Bob的Token余额:", token.balanceOf(BOB_ADDRESS));
    }

    function testDirectExecution() public {
        console2.log(unicode"测试：在单个交易中从Alice发送1 ETH给Bob并转账100代币给Bob");
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

        // 验证Alice的账户现在暂时表现为智能合约
        vm.startPrank(ALICE_ADDRESS);
        console2.log(unicode"Alice账户上的代码:", vm.toString(address(ALICE_ADDRESS).code));
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls);
        vm.stopPrank();

        assertEq(BOB_ADDRESS.balance, 1 ether);
        assertEq(token.balanceOf(BOB_ADDRESS), 100e18);
    }

    function testSponsoredExecution() public {
        console2.log(unicode"从Alice发送1 ETH到一个随机地址，而交易由Bob赞助");

        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        address recipient = makeAddr("recipient");

        calls[0] = BatchCallAndSponsor.Call({to: recipient, value: 1 ether, data: ""});

        // Alice签署一个委托，允许`implementation`代表她执行交易
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), ALICE_PK);

        // Bob附加Alice的签名委托并广播它
        vm.startBroadcast(BOB_PK);
        vm.attachDelegation(signedDelegation);

        // 验证Alice的账户现在暂时表现为智能合约
        bytes memory code = address(ALICE_ADDRESS).code;
        require(code.length > 0, "no code written to Alice");
        // console2.log("Alice账户上的代码:", vm.toString(code));

        // 调试随机数
        // console2.log("发送交易前的随机数:", BatchCallAndSponsor(ALICE_ADDRESS).nonce());

        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }

        bytes32 digest = keccak256(abi.encodePacked(BatchCallAndSponsor(ALICE_ADDRESS).nonce(), encodedCalls));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        // 预期事件。第一个参数应该是BOB_ADDRESS
        vm.expectEmit(true, true, true, true);
        emit BatchCallAndSponsor.CallExecuted(BOB_ADDRESS, calls[0].to, calls[0].value, calls[0].data);

        // 作为Bob，通过Alice临时分配的合约执行交易
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls, signature);

        // console2.log("发送交易后的随机数:", BatchCallAndSponsor(ALICE_ADDRESS).nonce());

        vm.stopBroadcast();

        assertEq(recipient.balance, 1 ether);
    }

    function testWrongSignature() public {
        console2.log(unicode"测试错误签名：执行应该回滚并显示'Invalid signature'。");
        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        calls[0] = BatchCallAndSponsor.Call({
            to: address(token),
            value: 0,
            data: abi.encodeCall(MockERC20.mint, (BOB_ADDRESS, 50))
        });

        // 构建编码的调用数据
        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }

        // Alice签署一个委托，允许`implementation`代表她执行交易
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), ALICE_PK);

        // Bob附加Alice的签名委托并广播它
        vm.startBroadcast(BOB_PK);
        vm.attachDelegation(signedDelegation);

        bytes32 digest = keccak256(abi.encodePacked(BatchCallAndSponsor(ALICE_ADDRESS).nonce(), encodedCalls));
        // 用错误的密钥签名（用Bob的而不是Alice的）
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BOB_PK, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Invalid signature");
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls, signature);
        vm.stopBroadcast();
    }

    function testReplayAttack() public {
        console2.log(unicode"测试重放攻击：重复使用相同的签名应该回滚。");
        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        calls[0] = BatchCallAndSponsor.Call({
            to: address(token),
            value: 0,
            data: abi.encodeCall(MockERC20.mint, (BOB_ADDRESS, 30))
        });

        // 构建编码的调用数据
        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data);
        }

        // Alice签署一个委托，允许`implementation`代表她执行交易
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), ALICE_PK);

        // Bob附加Alice的签名委托并广播它
        vm.startBroadcast(BOB_PK);
        vm.attachDelegation(signedDelegation);

        uint256 nonceBefore = BatchCallAndSponsor(ALICE_ADDRESS).nonce();
        bytes32 digest = keccak256(abi.encodePacked(nonceBefore, encodedCalls));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        // 第一次执行：应该成功
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls, signature);
        vm.stopBroadcast();

        // 尝试重放：重用相同的签名应该回滚，因为随机数已增加
        vm.expectRevert("Invalid signature");
        BatchCallAndSponsor(ALICE_ADDRESS).execute(calls, signature);
    }
}

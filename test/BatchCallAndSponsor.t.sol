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
    // 本地测试网络的默认账户
    address payable ALICE_ADDRESS;
    uint256 ALICE_PK;

    // Bob的地址和私钥（Bob将代表Alice执行交易）
    address BOB_ADDRESS;
    uint256 BOB_PK;

    // Alice将委托执行的合约
    BatchCallAndSponsor public implementation;

    // ERC-20 代币合约，用于铸造测试代币
    MockERC20 public token;

    event CallExecuted(address indexed to, uint256 value, bytes data);
    event BatchExecuted(uint256 indexed nonce, BatchCallAndSponsor.Call[] calls);

    function setUp() public {
        // 检查是否在真实网络上运行测试
        if (block.chainid != 31337) {
            // 从环境变量中加载账户信息
            ALICE_ADDRESS = payable(vm.envAddress("ALICE_ADDRESS"));
            ALICE_PK = vm.envUint("ALICE_PRIVATE_KEY");
            BOB_ADDRESS = vm.envAddress("BOB_ADDRESS");
            BOB_PK = vm.envUint("BOB_PRIVATE_KEY");
        } else {
            // 使用默认的Anvil测试账户
            ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
            ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
            BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
            BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
        }

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

    // 其余测试函数保持不变，它们将使用setUp中设置的变量
    function testDirectExecution() public {
        console2.log(unicode"测试：在单个交易中从Alice发送1 ETH给Bob并转账100代币给Bob");
        // 测试函数的其余部分不变...
        
        // ... 使用ALICE_ADDRESS, BOB_ADDRESS等变量 ...
    }

    function testSponsoredExecution() public {
        console2.log(unicode"从Alice发送1 ETH到一个随机地址，而交易由Bob赞助");
        // 测试函数的其余部分不变...
        
        // ... 使用ALICE_ADDRESS, BOB_ADDRESS等变量 ...
    }

    function testWrongSignature() public {
        console2.log(unicode"测试错误签名：执行应该回滚并显示'Invalid signature'。");
        // 测试函数的其余部分不变...
        
        // ... 使用ALICE_ADDRESS, BOB_ADDRESS等变量 ...
    }

    function testReplayAttack() public {
        console2.log(unicode"测试重放攻击：重复使用相同的签名应该回滚。");
        // 测试函数的其余部分不变...
        
        // ... 使用ALICE_ADDRESS, BOB_ADDRESS等变量 ...
    }
}
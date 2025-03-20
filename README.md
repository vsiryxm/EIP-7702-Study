# BatchCallAndSponsor

一个教学性项目，展示使用EIP-7702进行账户抽象和赞助交易执行。本项目使用Foundry进行部署、脚本编写和测试。

## 学习笔记
- [EIP-7702 多授权交易前端构建教程](./frontend-build.md)
- [EIP-7702 交易执行流程时序图](./sequence_diagram.md)
- [EIP-7702 后事件监听策略](./event.md)
- [Foundry 框架使用指南](./frontend-build.md)


## 概述

`BatchCallAndSponsor`合约通过验证随机数和批量调用数据上的签名来实现批量执行调用。它支持：
- **直接执行**：由智能账户自身执行。
- **赞助执行**：通过链下签名（由赞助商完成）。

通过在每次批量执行后递增的内部随机数提供重放保护。

## 特点

- 批量交易执行
- 使用ECDSA的链下签名验证
- 通过随机数递增实现重放保护
- 支持ETH和ERC-20代币转账

## 前提条件

- [Foundry](https://github.com/foundry-rs/foundry)
- Solidity ^0.8.20

## 运行项目

### 步骤1：安装Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
git clone https://github.com/quiknode-labs/qn-guide-examples.git
cd qn-guide-examples/ethereum/eip-7702
```

### 步骤2：安装依赖包并创建remappings.txt

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
forge remappings > remappings.txt
```

### 步骤3：运行本地网络

在终端运行以下命令，启动具有Prague硬分叉的本地网络：

```bash
anvil --hardfork prague
```

### 步骤4：构建合约

在另一个终端，运行以下命令构建合约：

```bash
forge build
```

### Step 5: 运行测试用例

构建合约后，运行以下命令执行测试用例。如果您想显示所有测试的堆栈跟踪，可以使用-vvvv标志代替`-vvv`：

```bash
forge test -vvv
```

输出应该如下所示：

```bash
Ran 4 tests for test/BatchCallAndSponsor.t.sol:BatchCallAndSponsorTest
[PASS] testDirectExecution() (gas: 128386)
Logs:
  Sending 1 ETH from Alice to Bob and transferring 100 tokens to Bob in a single transaction

[PASS] testReplayAttack() (gas: 114337)
Logs:
  Test replay attack: Reusing the same signature should revert.

[PASS] testSponsoredExecution() (gas: 110461)
Logs:
  Sending 1 ETH from Alice to a random address while the transaction is sponsored by Bob

[PASS] testWrongSignature() (gas: 37077)
Logs:
  Test wrong signature: Execution should revert with 'Invalid signature'.

Suite result: ok. 4 passed; 0 failed; 0 skipped;
```

#### Step 6: 运行脚本

现在您已经设置好项目，是时候运行部署脚本了。该脚本部署合约、铸造代币，并测试批量执行和赞助执行功能。

我们使用以下命令：
- **`--broadcast`**: 将交易广播到您的本地网络。
- **`--rpc-url 127.0.0.1:8545`**: 连接到您的本地网络。
- **`--tc BatchCallAndSponsorScript`**: 指定脚本的目标合约。

```bash
forge script ./script/BatchCallAndSponsor.s.sol --tc BatchCallAndSponsorScript --broadcast --rpc-url 127.0.0.1:8545
```



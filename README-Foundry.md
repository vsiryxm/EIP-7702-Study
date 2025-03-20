## Foundry框架

**Foundry是一个用Rust编写的闪电般快速、便携且模块化的以太坊应用开发工具包。**

Foundry包含：

-   **Forge**：以太坊测试框架（类似于Truffle、Hardhat和DappTools）。
-   **Cast**：与EVM智能合约交互、发送交易和获取链数据的瑞士军刀。
-   **Anvil**：本地以太坊节点，类似于Ganache、Hardhat Network。
-   **Chisel**：快速、实用且详细的Solidity REPL。

## 文档

https://book.getfoundry.sh/

## 使用

### 构建

```shell
$ forge build
```

### 测试

```shell
$ forge test
```

### 格式化

```shell
$ forge fmt
```

### Gas快照

```shell
$ forge snapshot
```

### 运行Anvil本地网络

```shell
$ anvil
```

### 部署

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast工具

Cast 是 Foundry 中的一个命令行工具，被设计为与以太坊区块链和智能合约交互的"瑞士军刀"。

```shell
$ cast <subcommand>
```

比如：
- `cast call` - 调用智能合约函数
- `cast send` - 发送交易
- `cast balance` - 查询地址余额
- `cast block` - 获取区块信息
- `cast tx` - 获取交易信息
- `cast gas` - 估算 gas 费用
- `cast abi-encode` - 进行 ABI 编码

### 帮助

```shell
$ forge --help
$ anvil --help
$ cast --help
```

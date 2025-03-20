# EIP-7702 交易执行流程时序图

https://www.mermaidchart.com/raw/835c7da6-1e20-421c-b384-44735564e814?theme=light&version=v0.1&format=svg

```
---
config:
  theme: forest
---
sequenceDiagram
    # 标题：EIP-7702 交易执行流程
    Wallet->>EOA: 创建一笔 EIP-7702 交易（类型 0x4）
    Note right of EOA: EOA 使用私钥<br>对交易进行签名验证
    EOA-->>Wallet: 返回签名后的交易数据
    Wallet->>EVM: 将签名交易广播到以太坊网络
    EVM->>EOA: 验证交易签名是否与 EOA 公钥匹配
    EVM->>Delegation: 从交易 data 字段加载委托代码
    Delegation->>EVM: 返回 
    EVM->>EVM: 将EOA临时变成智能账户<br>并部署委托代码到code字段
    EVM->>EVM: 执行委托代码中的智能合约逻辑
    alt Gas 赞助者支付（可选）
        EVM->>Sponsor: 向 Gas 赞助者请求支付 Gas 费用
        Note right of Sponsor: Gas 赞助者<br>确认并支付 Gas 费用
    else EOA 支付
        Note right of EOA: EOA 使用<br>自身余额支付 Gas 费用
    end
    EVM->>EVM: 交易完成后清理临时合约账户
    EVM-->>Wallet: 返回交易执行结果（成功/失败及日志）
```


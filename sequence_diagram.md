# EIP-7702 交易执行流程时序图

https://www.mermaidchart.com/raw/835c7da6-1e20-421c-b384-44735564e814?theme=light&version=v0.1&format=svg

```
---
config:
  theme: forest
---
sequenceDiagram
    title: EIP-7702 多授权交易执行流程 
    Wallet->>EOA: 创建一笔 EIP-7702 交易（类型 0x4）<br>包含多个授权和对应交易
    Note right of EOA: EOA 使用私钥<br>对交易进行签名
    EOA-->>Wallet: 返回签名后的交易数据
    Wallet->>EVM: 将签名交易广播到以太坊网络
    EVM->>EOA: 验证交易签名是否与 EOA 公钥匹配
    
    rect rgb(200, 220, 240)
    Note over EVM,EOA: 多授权循环开始 - 对于每对授权和交易
    
    loop 对于 authorizationList 中的每个授权
        EVM->>EVM: 从 authorizationList[i] 获取实现合约地址
        EVM->>ImplContract: 读取实现合约的代码
        ImplContract-->>EVM: 返回合约代码
        EVM->>EOA: 临时部署实现合约代码到 EOA 的 code 字段
        Note right of EOA: EOA 此时变为<br>智能合约账户
        
        EVM->>EOA: 执行对应的 transactions[i]
        
        alt Gas 赞助者支付（可选）
            EVM->>Sponsor: 向 Gas 赞助者请求支付 Gas 费用
            Sponsor-->>EVM: 确认并支付 Gas 费用
        else EOA 支付
            EOA-->>EVM: 使用自身余额支付 Gas 费用
        end
        
        EVM->>EOA: 清除 code 字段，恢复为普通 EOA
    end
    
    end
    
    EVM->>EVM: 所有授权和交易处理完毕
    EVM-->>Wallet: 返回交易整体执行结果（成功/失败及日志）
```


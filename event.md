# EIP-7702 后事件监听策略

EIP-7702 引入了一种新的交易执行模式，让 EOA 能够临时执行合约代码。这确实会对后端监听事件的方式产生影响，但核心机制仍然保留。让我为您详细解析 EIP-7702 前后事件监听的区别和应对策略。

## EIP-7702 前后事件监听比较

### EIP-7702 之前（传统模式）

在传统模式下，事件监听流程相对直接：

1. EOA 向合约 A 发送交易
2. 合约 A 执行代码并触发事件
3. 后端监听合约 A 的事件
4. 事件数据包含:
   - `address`: 合约 A 的地址（发出事件的合约）
   - `topics`: 事件签名和索引参数
   - `data`: 非索引参数
   - `blockNumber`, `transactionHash` 等区块链信息

### EIP-7702 之后（新模式）

在 EIP-7702 后，同样的操作可能会如下执行：

1. EOA 发送 EIP-7702 交易，带有实现合约授权
2. EOA 临时加载实现合约代码
3. EOA（现在拥有合约代码）执行交易并触发事件
4. 事件数据现在包含:
   - `address`: **EOA 的地址**（而不是实现合约地址）
   - `topics`: 事件签名和索引参数（不变）
   - `data`: 非索引参数（不变）
   - 其他区块链信息（不变）

## 关键区别

**最重要的区别是事件的发出地址**。在 EIP-7702 中，事件是从 EOA 地址发出的，而不是从原始实现合约地址发出的。这是因为代码是在 EOA 上下文中执行的。

## 后端监听策略调整

要适应 EIP-7702，您需要对后端监听策略进行以下调整：

### 1. 多地址监听

```javascript
// EIP-7702 之前（只监听合约地址）
web3.eth.subscribe('logs', {
  address: '0xContractAddress',
  topics: [web3.utils.sha3('Transfer(address,address,uint256)')]
});

// EIP-7702 之后（需要监听可能发出事件的所有 EOA 地址和合约地址）
web3.eth.subscribe('logs', {
  topics: [web3.utils.sha3('Transfer(address,address,uint256)')]
  // 不指定 address，监听所有地址的事件
});
```

### 2. 基于事件签名（而非地址）进行过滤

```javascript
// 接收所有匹配事件签名的日志
web3.eth.subscribe('logs', {
  topics: [web3.utils.sha3('Transfer(address,address,uint256)')]
})
.on('data', function(log) {
  // 处理所有来源的 Transfer 事件
  processTranferEvent(log);
});
```

### 3. 交易分析逻辑

```javascript
async function processTransaction(txHash) {
  const tx = await web3.eth.getTransaction(txHash);
  
  // 检查是否为 EIP-7702 交易（类型 0x4）
  if (tx.type === '0x4') {
    // 这是一个 EIP-7702 交易，解析授权列表和交易数据
    const decodedData = decodeEIP7702TransactionData(tx.data);
    
    // 针对 EIP-7702 交易的特殊处理
    // ...
  } else {
    // 常规交易处理
    // ...
  }
}
```

### 4. 事件来源分析

```javascript
function analyzeEventSource(log) {
  // 检查事件来源地址是否为 EOA 或合约
  web3.eth.getCode(log.address).then(code => {
    if (code === '0x') {
      // 事件来自 EOA - 可能是 EIP-7702 交易
      console.log('Event from EOA with EIP-7702:', log.address);
      // 可能需要查看原始交易以获取实现合约信息
    } else {
      // 事件来自常规合约
      console.log('Event from contract:', log.address);
    }
  });
}
```

### 5. 索引策略调整

在数据库中，您可能需要建立新的索引关系：

```sql
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  tx_hash VARCHAR(66) NOT NULL,
  event_emitter VARCHAR(42) NOT NULL, -- 可能是 EOA 或合约地址
  event_name VARCHAR(100) NOT NULL,
  implementation_contract VARCHAR(42), -- 可选，用于 EIP-7702 交易
  event_data JSONB NOT NULL,
  block_number BIGINT NOT NULL
);

-- 为交易类型创建索引
CREATE INDEX idx_tx_type ON transactions(tx_type);
-- 为事件发出者创建索引
CREATE INDEX idx_event_emitter ON events(event_emitter);
```

## 综合监听方案

以下是一个综合性的事件监听方案，适用于同时处理传统交易和 EIP-7702 交易：

```javascript
class EventListener {
  constructor(web3) {
    this.web3 = web3;
    this.eventSignatures = {
      'Transfer': '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
      'Approval': '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925',
      // 其他感兴趣的事件签名
    };
  }
  
  start() {
    // 监听所有交易
    this.web3.eth.subscribe('newBlockHeaders')
      .on('data', async (blockHeader) => {
        await this.processBlock(blockHeader.number);
      });
      
    // 直接监听感兴趣的事件签名
    this.web3.eth.subscribe('logs', {
      topics: [Object.values(this.eventSignatures)]
    })
    .on('data', (log) => {
      this.processEvent(log);
    });
  }
  
  async processBlock(blockNumber) {
    const block = await this.web3.eth.getBlock(blockNumber, true);
    
    for (const tx of block.transactions) {
      // 检查是否为 EIP-7702 交易
      if (tx.type === '0x4') {
        await this.processEIP7702Transaction(tx);
      }
    }
  }
  
  async processEIP7702Transaction(tx) {
    // 解析 EIP-7702 交易数据，提取授权列表和实现合约
    const { authorizationList } = decodeEIP7702Tx(tx.data);
    
    // 存储 EOA 与实现合约的关系
    for (const auth of authorizationList) {
      await db.query(
        'INSERT INTO eip7702_authorizations (tx_hash, eoa_address, implementation_contract) VALUES (?, ?, ?)',
        [tx.hash, tx.from, auth.contractAddress]
      );
    }
  }
  
  async processEvent(log) {
    // 获取事件签名
    const eventSignature = log.topics[0];
    const eventName = this.getEventNameFromSignature(eventSignature);
    
    // 检查事件发出者是否为 EOA
    const code = await this.web3.eth.getCode(log.address);
    const isEOA = code === '0x';
    
    if (isEOA) {
      // 检查是否来自 EIP-7702 交易
      const tx = await this.web3.eth.getTransaction(log.transactionHash);
      if (tx.type === '0x4') {
        // 从数据库中检索实现合约信息
        const implementations = await db.query(
          'SELECT implementation_contract FROM eip7702_authorizations WHERE tx_hash = ?',
          [log.transactionHash]
        );
        
        // 处理 EIP-7702 交易产生的事件
        await this.storeEvent(log, eventName, implementations);
      }
    } else {
      // 处理常规合约事件
      await this.storeEvent(log, eventName);
    }
  }
  
  async storeEvent(log, eventName, implementations = []) {
    // 将事件存储到数据库
    await db.query(
      'INSERT INTO events (tx_hash, block_number, event_emitter, event_name, implementation_contracts, event_data) VALUES (?, ?, ?, ?, ?, ?)',
      [
        log.transactionHash,
        log.blockNumber,
        log.address,
        eventName,
        JSON.stringify(implementations),
        JSON.stringify(log)
      ]
    );
  }
  
  getEventNameFromSignature(signature) {
    for (const [name, sig] of Object.entries(this.eventSignatures)) {
      if (sig === signature) return name;
    }
    return 'Unknown';
  }
}
```

## 核心建议总结

1. **监听事件签名而非地址**：不再仅监听特定合约地址，而是监听特定事件签名
   
2. **交易类型检查**：识别 EIP-7702 交易（类型 0x4）并特殊处理
   
3. **EOA 与实现合约映射**：维护 EOA 地址与其使用的实现合约地址的映射关系
   
4. **事件发出者分析**：区分常规合约事件与来自 EOA 的 EIP-7702 事件
   
5. **丰富事件元数据**：在事件数据中添加实现合约信息，方便后续分析

通过这些调整，您的后端系统将能够有效地处理和监听 EIP-7702 交易产生的事件，同时保持对传统交易的兼容性。
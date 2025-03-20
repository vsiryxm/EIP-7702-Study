# EIP-7702 多授权交易前端构建教程

下面是一个详细的前端示例，展示如何构建包含多个授权的 EIP-7702 交易。

## 完整代码示例

```javascript
// 导入必要的库和工具
import { createWalletClient, http, parseEther, encodeFunctionData } from 'viem'
import { mainnet } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'
import { eip7702Actions } from 'viem/experimental' // EIP-7702 的实验性支持

// 导入我们将使用的智能合约 ABI
import { 
  swapManagerAbi,     // 交换管理合约的 ABI
  lendingManagerAbi,  // 借贷管理合约的 ABI
  nftManagerAbi,      // NFT 管理合约的 ABI
  tokenAbi            // ERC20 代币合约的 ABI
} from './abis'

// 定义我们将使用的合约地址
const SWAP_MANAGER_ADDRESS = '0x1234567890123456789012345678901234567890'    // 交换管理合约地址
const LENDING_MANAGER_ADDRESS = '0x2345678901234567890123456789012345678901' // 借贷管理合约地址
const NFT_MANAGER_ADDRESS = '0x3456789012345678901234567890123456789012'     // NFT 管理合约地址

// 定义代币地址
const DAI_ADDRESS = '0x6B175474E89094C44Da98b954EedeAC495271d0F'   // DAI 代币地址
const USDC_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'  // USDC 代币地址
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'  // WETH 代币地址

/**
 * 执行多授权交易的主函数
 * 此函数将执行三种不同的操作:
 * 1. 在 DEX 上交换代币
 * 2. 在借贷平台上存款
 * 3. 购买 NFT
 */
async function executeMultiAuthorization() {
  // 步骤 1: 初始化钱包客户端
  // 使用私钥创建账户对象 (注意: 在生产环境中，永远不要硬编码私钥)
  const account = privateKeyToAccount('0xYOUR_PRIVATE_KEY_HERE')
  
  // 创建钱包客户端，连接到以太坊主网
  const walletClient = createWalletClient({
    account,                 // 设置账户
    chain: mainnet,          // 指定链 (主网)
    transport: http(),       // 使用 HTTP 传输层
  }).extend(eip7702Actions()) // 扩展客户端支持 EIP-7702 功能
  
  // 步骤 2: 为每个实现合约创建授权
  // 为交换操作创建授权
  const swapAuthorization = await walletClient.signAuthorization({
    contractAddress: SWAP_MANAGER_ADDRESS, // 将执行委托给交换管理合约
  })
  
  // 为借贷操作创建授权
  const lendingAuthorization = await walletClient.signAuthorization({
    contractAddress: LENDING_MANAGER_ADDRESS, // 将执行委托给借贷管理合约
  })
  
  // 为 NFT 操作创建授权
  const nftAuthorization = await walletClient.signAuthorization({
    contractAddress: NFT_MANAGER_ADDRESS, // 将执行委托给 NFT 管理合约
  })
  
  // 步骤 3: 创建每个操作的交易数据
  
  // 3.1: 准备代币交换操作数据
  // 将 100 DAI 换成 WETH，设置 0.04 WETH 为最小接收量
  const swapData = encodeFunctionData({
    abi: swapManagerAbi,       // 使用交换管理合约的 ABI
    functionName: 'executeSwap', // 调用 executeSwap 函数
    args: [
      DAI_ADDRESS,           // 输入代币地址 (DAI)
      WETH_ADDRESS,          // 输出代币地址 (WETH)
      parseEther('100'),     // 输入金额 (100 DAI)
      parseEther('0.04'),    // 最小输出金额 (0.04 WETH)
      [DAI_ADDRESS, WETH_ADDRESS] // 交换路径
    ]
  })
  
  // 3.2: 准备借贷操作数据
  // 存入 50 USDC 到借贷平台
  const lendingData = encodeFunctionData({
    abi: lendingManagerAbi,    // 使用借贷管理合约的 ABI
    functionName: 'deposit',   // 调用 deposit 函数
    args: [
      USDC_ADDRESS,          // 存款资产 (USDC)
      50_000_000,            // 存款金额 (50 USDC，6 位小数)
      account.address,       // 受益人 (自己)
      0                      // 推荐码
    ]
  })
  
  // 3.3: 准备 NFT 购买操作数据
  // 尝试以 1 ETH 的价格购买 ID 为 123 的 NFT
  const nftData = encodeFunctionData({
    abi: nftManagerAbi,        // 使用 NFT 管理合约的 ABI
    functionName: 'purchaseNFT', // 调用 purchaseNFT 函数
    args: [
      '0x60F80121C31A0d46B5279700f9DF786054aa5eE5', // NFT 市场地址
      '0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D', // NFT 集合地址
      123,                   // NFT ID
      parseEther('1')        // 最高价格 (1 ETH)
    ]
  })
  
  // 步骤 4: 构建交易对象数组
  // 注意 data 的顺序与上文对实现合约授权的顺序一一对应
  const transactions = [
    {
      // 交换操作
      to: account.address,     // 交易发送到用户自己的地址
      data: swapData,          // 交换函数调用数据
      value: 0n                // 不发送 ETH
    },
    {
      // 借贷操作
      to: account.address,     // 交易发送到用户自己的地址
      data: lendingData,       // 借贷函数调用数据
      value: 0n                // 不发送 ETH
    },
    {
      // NFT 购买操作
      to: account.address,     // 交易发送到用户自己的地址
      data: nftData,           // NFT 购买函数调用数据
      value: parseEther('1')   // 发送 1 ETH 用于购买
    }
  ]
  
  // 步骤 5: 发送包含多个授权的交易
  try {
    // 使用 EIP-7702 发送批量交易
    const transactionHash = await walletClient.sendTransaction({
      // 包含所有授权的列表
      authorizationList: [
        swapAuthorization,
        lendingAuthorization,
        nftAuthorization
      ],
      // 批量交易数据
      batch: transactions
    })
    // `transactions[0]` 对应着 `authorizationList[0]` (即 `swapAuthorization`)
    // `transactions[1]` 对应着 `authorizationList[1]` (即 `lendingAuthorization`) 
    // `transactions[2]` 对应着 `authorizationList[2]` (即 `nftAuthorization`)

    // 这里涉及到3个被授权的合约代码，当这笔多个授权合约的交易发送到EVM时，EVM会依次加载不同合约代码并执行它们：
    // 加载 SWAP_MANAGER_ADDRESS 的代码到 EOA 上
    // 执行 transactions[0] (交换操作)
    // 清除 EOA 上的代码
    // 加载 LENDING_MANAGER_ADDRESS 的代码到 EOA 上
    // 执行 transactions[1] (借贷操作)
    // 清除 EOA 上的代码
    // 加载 NFT_MANAGER_ADDRESS 的代码到 EOA 上
    // 执行 transactions[2] (NFT 购买操作)
    // 清除 EOA 上的代码，EOA 完全恢复到原始状态

    console.log('交易已发送，哈希:', transactionHash)
    
    // 等待交易确认
    const receipt = await walletClient.waitForTransactionReceipt({
      hash: transactionHash
    })
    
    console.log('交易已确认，状态:', receipt.status)
    return { hash: transactionHash, receipt }
    
  } catch (error) {
    console.error('交易失败:', error)
    throw error
  }
}

// 步骤 6: 检查代币是否授权 (通常需要在交换操作前执行)
async function checkAndApproveTokens() {
  // 创建标准钱包客户端 (不需要 EIP-7702 扩展)
  const account = privateKeyToAccount('0xYOUR_PRIVATE_KEY_HERE')
  const walletClient = createWalletClient({
    account,
    chain: mainnet,
    transport: http(),
  })
  
  // 检查 DAI 授权
  const daiAllowance = await walletClient.readContract({
    address: DAI_ADDRESS,
    abi: tokenAbi,
    functionName: 'allowance',
    args: [account.address, SWAP_MANAGER_ADDRESS]
  })
  
  // 如果 DAI 授权不足，则授权
  if (daiAllowance < parseEther('100')) {
    console.log('授权 DAI...')
    const approveTx = await walletClient.writeContract({
      address: DAI_ADDRESS,
      abi: tokenAbi,
      functionName: 'approve',
      args: [SWAP_MANAGER_ADDRESS, parseEther('1000')] // 授权 1000 DAI
    })
    
    await walletClient.waitForTransactionReceipt({
      hash: approveTx
    })
    console.log('DAI 授权完成')
  }
  
  // 检查 USDC 授权
  const usdcAllowance = await walletClient.readContract({
    address: USDC_ADDRESS,
    abi: tokenAbi,
    functionName: 'allowance',
    args: [account.address, LENDING_MANAGER_ADDRESS]
  })
  
  // 如果 USDC 授权不足，则授权
  if (usdcAllowance < 50_000_000n) {
    console.log('授权 USDC...')
    const approveTx = await walletClient.writeContract({
      address: USDC_ADDRESS,
      abi: tokenAbi,
      functionName: 'approve',
      args: [LENDING_MANAGER_ADDRESS, 1_000_000_000n] // 授权 1000 USDC
    })
    
    await walletClient.waitForTransactionReceipt({
      hash: approveTx
    })
    console.log('USDC 授权完成')
  }
}

// 步骤 7: 组合前面的函数，执行完整流程
async function performMultiContractOperations() {
  try {
    // 首先检查并授权代币
    await checkAndApproveTokens()
    
    // 然后执行多授权交易
    const result = await executeMultiAuthorization()
    
    console.log('所有操作成功完成!')
    return result
  } catch (error) {
    console.error('操作失败:', error)
    throw error
  }
}

// 导出主函数，供其他模块使用
export { performMultiContractOperations }
```

## 主要步骤分解

让我来分解这个示例中的主要步骤：

### 1. 初始化和导入必要组件

```javascript
import { createWalletClient, http, parseEther, encodeFunctionData } from 'viem'
import { mainnet } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'
import { eip7702Actions } from 'viem/experimental'
```

这些导入提供了与以太坊交互所需的工具，特别是 `eip7702Actions` 提供了对 EIP-7702 的支持。

### 2. 创建钱包客户端

```javascript
const account = privateKeyToAccount('0xYOUR_PRIVATE_KEY_HERE')
const walletClient = createWalletClient({
  account,
  chain: mainnet,
  transport: http(),
}).extend(eip7702Actions())
```

这段代码创建了一个钱包客户端，并通过 `.extend(eip7702Actions())` 添加对 EIP-7702 的支持。

### 3. 为每个实现合约创建授权

```javascript
const swapAuthorization = await walletClient.signAuthorization({
  contractAddress: SWAP_MANAGER_ADDRESS,
})
```

每个授权指定一个实现合约，该合约将暂时接管您账户的执行权限。

### 4. 准备函数调用数据

```javascript
const swapData = encodeFunctionData({
  abi: swapManagerAbi,
  functionName: 'executeSwap',
  args: [
    DAI_ADDRESS,
    WETH_ADDRESS,
    parseEther('100'),
    parseEther('0.04'),
    [DAI_ADDRESS, WETH_ADDRESS]
  ]
})
```

为每个操作创建 ABI 编码的函数调用数据。

### 5. 构建交易对象

```javascript
const transactions = [
  {
    to: account.address,
    data: swapData,
    value: 0n
  },
  // ...其他交易
]
```

每个交易对象包含目标地址、函数调用数据和要发送的 ETH 值。

### 6. 发送多授权交易

```javascript
const transactionHash = await walletClient.sendTransaction({
  authorizationList: [
    swapAuthorization,
    lendingAuthorization,
    nftAuthorization
  ],
  batch: transactions
})
```

`authorizationList` 包含所有授权，`batch` 包含所有交易数据。

## 注意事项

1. **安全性**: 永远不要在代码中硬编码私钥，尤其是在前端代码中。应该使用钱包连接器（如 MetaMask）或安全的密钥管理解决方案。

2. **代币授权**: 在执行代币交换或转移之前，需要确保合约已获得足够的授权。示例中的 `checkAndApproveTokens` 函数展示了这一点。

3. **错误处理**: 在生产环境中，需要更健壮的错误处理和用户反馈机制。

4. **Gas 估算**: 多授权交易可能消耗大量 gas，应该在执行前进行估算并向用户显示。

5. **链兼容性**: 确保目标链支持 EIP-7702，目前这是一个实验性功能。

## 与用户界面集成

在实际应用中，您可能需要将此功能与用户界面集成。以下是一个简单的 React 组件示例：

```jsx
import React, { useState } from 'react'
import { performMultiContractOperations } from './eip7702Helper'

function MultiOperationButton() {
  const [loading, setLoading] = useState(false)
  const [txHash, setTxHash] = useState('')
  const [error, setError] = useState('')
  
  const handleClick = async () => {
    setLoading(true)
    setError('')
    
    try {
      const result = await performMultiContractOperations()
      setTxHash(result.hash)
    } catch (err) {
      setError(err.message || '交易失败')
    } finally {
      setLoading(false)
    }
  }
  
  return (
    <div>
      <button 
        onClick={handleClick} 
        disabled={loading}
      >
        {loading ? '处理中...' : '执行多合约操作'}
      </button>
      
      {txHash && (
        <div>
          <p>交易已发送!</p>
          <a 
            href={`https://etherscan.io/tx/${txHash}`} 
            target="_blank" 
            rel="noopener noreferrer"
          >
            在 Etherscan 上查看
          </a>
        </div>
      )}
      
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  )
}

export default MultiOperationButton
```

## 总结

EIP-7702 多授权交易提供了强大的功能，允许在一个交易中执行多个不同实现合约的操作。这不仅可以提高用户体验（通过减少用户需要确认的交易数量），还能降低 gas 费用，并启用更复杂的链上交互模式。

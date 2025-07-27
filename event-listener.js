const { ethers } = require('ethers');

// 配置
const RPC_URL = 'http://127.0.0.1:8545'; // 替换为你的RPC URL
const CONTRACT_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'; // 替换为你的NFTMarket合约地址

// NFTMarket合约ABI（只包含事件部分）
const CONTRACT_ABI = [
    "event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price)",
    "event NFTBought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price)"
];

class NFTMarketEventListener {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(RPC_URL);
        this.contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, this.provider);
        this.isListening = false;
    }

    // 启动事件监听
    async startListening() {
        if (this.isListening) {
            console.log('事件监听器已经在运行中...');
            return;
        }

        console.log('🚀 开始监听NFTMarket合约事件...');
        console.log(`合约地址: ${CONTRACT_ADDRESS}`);
        console.log('='.repeat(50));

        this.isListening = true;

        // 监听NFT上架事件
        this.contract.on('NFTListed', (tokenId, seller, price, event) => {
            console.log('📋 NFT上架事件:');
            console.log(`  Token ID: ${tokenId.toString()}`);
            console.log(`  卖家地址: ${seller}`);
            console.log(`  价格: ${ethers.formatEther(price)} ETH`);
            console.log(`  交易哈希: ${event.log.transactionHash}`);
            console.log(`  区块号: ${event.log.blockNumber}`);
            console.log(`  时间: ${new Date().toLocaleString()}`);
            console.log('-'.repeat(40));
        });

        // 监听NFT购买事件
        this.contract.on('NFTBought', (tokenId, buyer, seller, price, event) => {
            console.log('💰 NFT购买事件:');
            console.log(`  Token ID: ${tokenId.toString()}`);
            console.log(`  买家地址: ${buyer}`);
            console.log(`  卖家地址: ${seller}`);
            console.log(`  成交价格: ${ethers.formatEther(price)} ETH`);
            console.log(`  交易哈希: ${event.log.transactionHash}`);
            console.log(`  区块号: ${event.log.blockNumber}`);
            console.log(`  时间: ${new Date().toLocaleString()}`);
            console.log('-'.repeat(40));
        });

        // 监听提供者错误
        this.provider.on('error', (error) => {
            console.error('❌ 提供者错误:', error);
        });

        console.log('✅ 事件监听器已启动，等待事件...');
    }

    // 停止事件监听
    stopListening() {
        if (!this.isListening) {
            console.log('事件监听器未在运行');
            return;
        }

        this.contract.removeAllListeners();
        this.provider.removeAllListeners();
        this.isListening = false;
        console.log('🛑 事件监听器已停止');
    }

    // 获取历史事件
    async getHistoricalEvents(fromBlock = 0, toBlock = 'latest') {
        console.log('📚 获取历史事件...');

        try {
            // 获取历史上架事件
            const listedEvents = await this.contract.queryFilter(
                this.contract.filters.NFTListed(),
                fromBlock,
                toBlock
            );

            // 获取历史购买事件
            const boughtEvents = await this.contract.queryFilter(
                this.contract.filters.NFTBought(),
                fromBlock,
                toBlock
            );

            console.log(`找到 ${listedEvents.length} 个上架事件`);
            console.log(`找到 ${boughtEvents.length} 个购买事件`);

            // 打印历史上架事件
            listedEvents.forEach((event, index) => {
                const { tokenId, seller, price } = event.args;
                console.log(`📋 历史上架事件 #${index + 1}:`);
                console.log(`  Token ID: ${tokenId.toString()}`);
                console.log(`  卖家: ${seller}`);
                console.log(`  价格: ${ethers.formatEther(price)} ETH`);
                console.log(`  区块: ${event.blockNumber}`);
                console.log(`  交易哈希: ${event.transactionHash}`);
                console.log('-'.repeat(30));
            });

            // 打印历史购买事件
            boughtEvents.forEach((event, index) => {
                const { tokenId, buyer, seller, price } = event.args;
                console.log(`💰 历史购买事件 #${index + 1}:`);
                console.log(`  Token ID: ${tokenId.toString()}`);
                console.log(`  买家: ${buyer}`);
                console.log(`  卖家: ${seller}`);
                console.log(`  价格: ${ethers.formatEther(price)} ETH`);
                console.log(`  区块: ${event.blockNumber}`);
                console.log(`  交易哈希: ${event.transactionHash}`);
                console.log('-'.repeat(30));
            });

        } catch (error) {
            console.error('❌ 获取历史事件失败:', error);
        }
    }
}

// 主函数
async function main() {
    const listener = new NFTMarketEventListener();

    // 处理程序退出
    process.on('SIGINT', () => {
        console.log('\n收到退出信号...');
        listener.stopListening();
        process.exit(0);
    });

    try {
        // 获取历史事件（可选）
        // await listener.getHistoricalEvents();

        // 启动实时监听
        await listener.startListening();

    } catch (error) {
        console.error('❌ 启动监听器失败:', error);
        process.exit(1);
    }
}

// 运行主函数
if (require.main === module) {
    main();
}

module.exports = NFTMarketEventListener;
# Foundry Raffle (Lottery) Smart Contract (TEST)


A decentralized, automated raffle smart contract using **Chainlink VRF** for provably fair random numbers and **Chainlink Automation** for trustless execution.



## 🛠 Features
- **Fairness**: Powered by Chainlink VRF v2.5.
- **Automation**: Fully autonomous prize distribution using Chainlink Automation.
- **Security**: Robust test suite with 80% logic coverage goal.

## 🚀 Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation
```bash
git clone https://github.com/1046616906/foundry-smart-contract.git
cd foundry-raffle
forge install

# Run all tests
forge test

# Check gas snapshots
forge snapshot

# View coverage report
forge coverage --report lcov

📜 Deployment
To deploy to Sepolia testnet, ensure you have your .env configured:
source .env
forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --account myKey --broadcast --verify
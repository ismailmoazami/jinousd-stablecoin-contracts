include .env

build :; forge build 

deploy-token-sepolia :; forge script script/DeployJino.sol --broadcast --rpc-url $(SEPOLIA_RPC_URL) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --account myaccount -vvvv
# Jino Stablecoin Engine

This project implements a stablecoin system called Jino, featuring an overcollateralized stablecoin (JinoUSD) and its management engine.

## Overview

The Jino Stablecoin Engine is a Solidity-based smart contract system that allows users to mint JinoUSD tokens by depositing collateral in the form of other cryptocurrencies (currently supporting WETH and WBTC). The system ensures that the stablecoin remains overcollateralized to maintain its stability and value.

## Key Features

- Deposit collateral (WETH, WBTC)
- Mint JinoUSD tokens
- Withdraw collateral
- Liquidation mechanism to maintain system health
- Oracle integration for real-time price feeds

## Smart Contracts

- `StablecoinEngine.sol`: Main contract managing collateral, minting, and system parameters
- `JinoUSD.sol`: ERC20 token contract for the JinoUSD stablecoin
- `OracleLib.sol`: Library for handling price feed data from Chainlink oracles

## Testing

The project includes comprehensive tests, including:

- Unit tests for individual contract functions
- Integration tests for complex interactions
- Invariant tests to ensure system-wide properties are maintained

Tests are written using the Foundry framework and can be found in the `test/` directory.

## Setup and Deployment

1. Install dependencies:
   ```
   forge install
   ```

2. Compile contracts:
   ```
   forge build
   ```

3. Run tests:
   ```
   forge test
   ```

4. Deploy (adjust network and parameters as needed):
   ```
   forge script script/DeployEngine.s.sol:DeployEngine --rpc-url $RPC_URL --broadcast --verify -vvvv
   ```

## Security Considerations

- The system relies on accurate price feeds. Ensure oracles are reliable and up-to-date.
- The contract includes reentrancy guards and checks for common vulnerabilities.
- Regular audits are recommended to ensure the system's security as it evolves.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your proposed changes.

## License

This project is licensed under the MIT License.

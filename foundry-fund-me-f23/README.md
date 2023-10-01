## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
$ forge coverage --fork-url $SEPOLIA_RPC_URL
$ forge test --match-test testPriceFeedVersionIsAccurate -vvv --fork-url $SEPOLIA_RPC_URL
```

### Format

```shell
$ forge fmt
```
```bash
// https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f
forge coverage --report lcov
sudo apt install lcov
genhtml -o report --branch-coverage lcov.info
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
make deploy-sepolia
```
### Cast

```shell
$ cast <subcommand>
```

### Interact
```bash
// --broadcast sends it to the network
forge script script/Interactions.s.sol:FundFundMe --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
forge inspect FundMe storageLayout

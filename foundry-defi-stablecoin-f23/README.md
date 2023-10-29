1. Ancored/Pegged -> $1.00
    - Chainlink price feed
2. Algorithmic -> Decentralized minting & burning
    - Only mint with enough collateral
3. Colateral type -> Exogenous - crypto (ETH)
    - wETH & wBTC

What are our project's invariants/properties?
Invariant - Property of our system that should always hold.

Example:
    - The baloon is unpoppable(unbrandable) -> The invariant is It can not be popped

Fuzz/Invariant test:
    - Test same function with different (random) parameter values

Invariant test - Stateful (random data & Random function calls to many functions)
            - Different users/msg.sender

Fuzz test - Stateless (Random data to one function)

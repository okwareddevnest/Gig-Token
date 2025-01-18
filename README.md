# GIG Token (TRC-20)

A TRC-20 compliant token with advanced features including temporary balance injection, untraceable transactions, and time-based expiration.

## Features

- Token Name: GIG
- Symbol: GIG
- Decimals: 6
- Total Supply: 10 million tokens
- Temporary Balance Injection
- Untraceable Transactions
- 120-day Expiration Mechanism
- Self-Destruction Capability

## Smart Contract Files

- `GIGToken.sol`: Main token contract
- `ITRC20.sol`: TRC-20 interface
- `SafeMath.sol`: Safe mathematical operations
- `Ownable.sol`: Ownership management

## Deployment Instructions

1. Install TronBox and configure your private key in `tronbox.js`
2. Compile the contracts:
   ```bash
   tronbox compile
   ```

3. Deploy to Testnet:
   ```bash
   tronbox migrate --network shasta
   ```

4. Deploy to Mainnet:
   ```bash
   tronbox migrate --network mainnet
   ```

## Interacting with the Contract using TronWeb

```javascript
// Initialize TronWeb
const TronWeb = require('tronweb');
const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    privateKey: 'your_private_key'
});

// Contract instance
const contract = await tronWeb.contract().at('CONTRACT_ADDRESS');

// Check balance
const balance = await contract.balanceOf('ADDRESS').call();

// Transfer tokens
await contract.transfer('RECIPIENT_ADDRESS', amount).send();

// Inject temporary balance (owner only)
await contract.injectTemporaryBalance('WALLET_ADDRESS', amount).send();

// Check if expired
const isExpired = await contract.isExpired().call();

// Self-destruct (owner only, after expiration)
await contract.selfDestruct().send();
```

## Security Considerations

1. The contract includes a 120-day expiration mechanism
2. Only the owner can inject temporary balances
3. Transactions are obfuscated using keccak256 hashing
4. Self-destruction is only possible after expiration
5. All mathematical operations use SafeMath for overflow protection

## Important Notes

- The contract will expire 120 days after deployment
- Temporary balances are valid for 120 days from injection
- Transaction details are hashed for privacy
- The contract can be destroyed by the owner after expiration

## License

MIT License 
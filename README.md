# BitcoinBlockchain.jl
Julia package for analyzing the Bitcoin blockchain via the API provided by https://blockchain.info/

## Installation

```
Pkg.clone("https://github.com/stejin/DandelionWebSockets.jl.git")
Pkg.clone("https://github.com/stejin/BitcoinBlockchain.jl.git")
```

## Usage

```
using BitcoinBlockchain

handler = BitcoinBlockchainHandler()

BitcoinBlockchain.connect(handler)

transaction(x) = global latest_transaction = x
block(b) = global latest_block = b

subscribe_unconfirmed_transcations(handler, transaction)
subscribe_new_blocks(handler, block)

# Wait for new transaction

sleep(5)

latest_transaction

# Wait for new block

#latest_block
```

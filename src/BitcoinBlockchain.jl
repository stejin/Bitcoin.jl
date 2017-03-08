module BitcoinBlockchain

  export  BitcoinBlockchainHandler,
          connect,
          subscribe_unconfirmed_transcations,
          subscribe_new_blocks,
          get_block,
          get_transaction,
          get_address

  include("client.jl")

end

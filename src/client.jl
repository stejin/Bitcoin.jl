using JSON
using Requests
import Requests: URI, post

using DandelionWebSockets
# Explicitly import the callback functions that we're going to add more methods for.
import DandelionWebSockets: on_text, on_binary,
                            state_connecting, state_open, state_closing, state_closed

type BitcoinBlockchainHandler <: WebSocketHandler
  client::WSClient
  stop_channel::Channel{Any}
  debug::Bool
  op_callbacks::Dict
  max_attempts::Int

  BitcoinBlockchainHandler() = new(WSClient(), Channel{Any}(3), false, Dict(), 6)

end

function getResult(handler, url, data = Dict())
  headers = Dict("Content-Type" => "application/json")
  attempt = 1
  resp = post(url; headers = headers, data = JSON.json(data))
  # Retry if service temporarily not available
  while resp.status == 503 && attempt < handler.max_attempts
    sleep(attempt) #increase wait time by one second for each failed attempt
    attempt += 1
    resp = post(url; headers = headers, data = JSON.json(data))
  end
  if resp.status == 503
    error("Aborting request with url: $url, data: $data after $(handler.max_attempts) attempts")
  elseif resp.status != 200
    error("$(resp.status): Error executing the request with url: $url, data: $data - $resp")
  else
    try
      parsedresp = Requests.json(resp)
      if "error" in keys(parsedresp)
        error("Error parsing response to request with url: $url, data: $dat - $(parsedresp["error"])")
      end
      parsedresp
    catch e
      error("Error parsing response to request with url: $url, data: $data - $resp")
    end
  end
end

# These are called when you get text/binary frames, respectively.
on_text(handler::BitcoinBlockchainHandler, s::String)         = onMessage(handler, s, false)
on_binary(handler::BitcoinBlockchainHandler, data::Vector{UInt8}) = onMessage(handler, data, true)

function onMessage(handler::BitcoinBlockchainHandler, payload, isBinary)
  if handler.debug
    isBinary && println("Binary message received: $(length(payload)) bytes.")
    !isBinary && println("Text message received: $payload.")
  end

  try

    responseEventInfo = JSON.parse(payload)

    # ping response
    responseEventInfo["op"] == "pong" && return
    handle_command(handler, responseEventInfo)

  catch e
    error("Error processing payload: $payload: $e")
  end
end

function sendMessage(handler::BitcoinBlockchainHandler, payload, isBinary)
  handler.debug && println("Sending: $payload")
  isBinary && send_binary(handler.client, payload)
  !isBinary && send_text(handler.client, String(payload))
end

# These are called when the WebSocket state changes.

state_connecting(::BitcoinBlockchainHandler) = println("State: CONNECTING")

# Called when the connection is open, and ready to send/receive messages.
function state_open(handler::BitcoinBlockchainHandler)
  println("State: OPEN")
  ping(handler)
end

state_closing(handler::BitcoinBlockchainHandler) = println("State: CLOSING")
state_closed(handler::BitcoinBlockchainHandler) = println("State: CLOSED")

function handle_command(handler::BitcoinBlockchainHandler, eventInfo)
  handler.debug && println("HANDLE COMMAND")
  # Server told us to do something.
  op = eventInfo["op"]
  if haskey(handler.op_callbacks, op)
    cb = handler.op_callbacks[op]
    cb(eventInfo)
  end
end

function publish(data)
  println("Publish: $(JSON.json(data))")
end

function subscribe(handler, op, publish_key, publish_callback)
  sendMessage(handler, json(Dict("op" => op)), false)
  handler.op_callbacks[publish_key] = publish_callback
  handler.debug && println("Subscribed $op")
end

function unsubscribe(handler, op, publish_key)
  delete!(handler.op_callbacks, publish_key)
  handler.debug && println("Unsubscribed $op")
end


function ping(handler)
  @schedule begin
    while true
      sleep(30)
      sendMessage(handler, json(Dict("op" => "ping")), false)
    end
  end
end

function connect(handler::BitcoinBlockchainHandler)
  uri = URI("wss://ws.blockchain.info/inv")
  println("Connecting to $uri")
  wsconnect(handler.client, uri, handler)
end

subscribe_unconfirmed_transcations(handler, publish_callback = subscribe) = subscribe(handler, "unconfirmed_sub", "utx", publish_callback)
subscribe_new_blocks(handler, publish_callback = subscribe) = subscribe(handler, "blocks_sub", "block", publish_callback)

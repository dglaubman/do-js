root = exports ? this

root.loads =
  L : "Low"
  M : "Moderate"
  H: "High"

root.currentLoad = root.loads.L
root.setLoad = (l) -> root.currentLoad = l

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, topic, pname, interval = 5000 ) ->
  timerFn = ->
    setInterval ( ->
      exchange.publish topic, "name: #{pname}, load: #{root.currentLoad}"
      ) , interval

   exchange = conn.exchange 'servers', options = { type: 'topic', autodelete: false }, timerFn



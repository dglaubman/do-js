root = exports ? this

root.bumpLoad = (l) ->
  currentLoad += (l)
  pulse()

pulse = ->
currentLoad = 0

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, topic, pname, interval = 5000 ) ->

  pulse = ->
    exchange.publish topic, "name: #{pname}, load: #{currentLoad}"
  timerFn = ->
    pulse()
    setInterval ( ->
      pulse()
      ) , interval
  exchange = conn.exchange 'servers', options = { type: 'topic', autodelete: false }, timerFn




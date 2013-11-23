root = exports ? this

root.bumpLoad = (l) ->
  currentLoad.push l
  pulse()

pulse = ->
currentLoad = []

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, serverX, topic, pname, interval = 5000 ) ->

  pulse = ->
    exchange.publish topic, "name|#{pname}|load|#{currentLoad}"
  timerFn = ->
    pulse()
    setInterval ( ->
      pulse()
      ) , interval
  exchange = conn.exchange serverX, options = { type: 'topic', autodelete: false }, timerFn


root = exports ? this
_ = require 'underscore'
{log, error} = require './log'

root.bumpLoad = (l) ->

root.sendStatistic = (l) ->
  currentLoss.push l
  log l

pulse = ->
currentLoss = []

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, serverX, topic, rak, pid, interval = 500 ) ->
  pulse = ->
    try
      exchange.publish topic, "rak|#{rak}|pid|#{pid}|loss|#{currentLoss}"
    catch e
      error e
  timerFn = ->
    pulse()
    setInterval ( ->
      pulse()
      currentLoss = []
      ) , interval
  exchange = conn.exchange serverX, options = { type: 'topic', autodelete: false }, timerFn


root = exports ? this
_ = require 'underscore'
{log, error} = require './log'
{Stat} = require './msgs'

root.sendStatistic = (l) ->
  currentLoss.push l
  log l

pulse = ->
currentLoss = [0]

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, serverX, topic, track, pname, interval = 100 ) ->
  pulse = ->
    try
      if not _.isEmpty currentLoss
        exchange.publish topic, Stat(track, pname, currentLoss.join(','))
        currentLoss = []
    catch e
      error e
  timerFn = ->
    pulse()
    setInterval ( ->
        pulse()
      ) , interval
  exchange = conn.exchange serverX, options = { type: 'topic', autodelete: false }, timerFn


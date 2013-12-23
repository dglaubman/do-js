root = exports ? this
_ = require 'underscore'
{log, error} = require './log'
{Stat} = require './msgs'

MAXLEN = 64

root.sendStatistic = (l) ->
  if currentLoss.length is MAXLEN
    log "sendStatistic queue len is #{MAXLEN}, draining queue."
    pulse()
  currentLoss.push l

pulse = ->
currentLoss = []

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, serverX, topic, track, pname, interval = 50 ) ->
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


# coffee:  publish a sequence of test payloads
#
# usage: start feed --signal <signal> --track <track>  --maxLoss <maxLoss> [-v] [--iter <iter = 1>]
# secondary options: [--xsignal <signalX>]

semver = '0.1.1'                  # Semantic versioning: see semver.org

_ = require 'underscore'
Lazy = require 'lazy.js'
amqp = require 'amqp'
{argv} = require 'optimist'
{logger, log, trace, traceAll, error, fatal} = require './log'

# Init log
logger argv, "feed: "

# Parse input arguments, set up log
name    = "feed"
signal = argv.signal           or fatal 'must specify --signal'
id = argv.id                   or fatal 'must specify --id'
iter = argv.iter               or 1
track = argv.track             or fatal "must specify --track"
maxLoss = argv.maxLoss         or 0

# Set up AMQP Exchanges
host    = argv.host            or 'localhost'
vhost   = argv.vhost           or "v#{semver}"
xsignal = argv.xsignal         or 'signalX'

format = (elapsed) ->
  [secs, nanos] = elapsed
  switch
    when secs is 0
      "#{(nanos / 1e6).toFixed 3}ms"
    else
      "#{secs}s #{(elapsed[1]/ 1e6).toFixed 0}ms"

genLoss = (n) ->
  i = 0
  Lazy.generate( ->  Math.random() )
    .map( (e) -> [ { loss : (e * maxLoss), event : i++ } ] )
    .take n

connection = amqp.createConnection( { host, vhost  } )

connection.on 'ready', =>
  try
    trace "connected to amqp on #{host}"
    signalX = connection.exchange xsignal, options = {
      type: 'topic'
      autodelete: false }, ->
        trace "exchange #{xsignal} ok"

        start = process.hrtime()
        genLoss(iter).each (payload) ->
          trace payload
          newmsg = JSON.stringify {
            ver: semver
            id: id++
            trackIds: [argv.track]
            payload: payload
          }
          # signal completion
          signalX.publish signal, newmsg
        elapsed = process.hrtime start
        log "#{iter} iterations in #{format elapsed}"
        process.exit 0
  catch e
    fatal e


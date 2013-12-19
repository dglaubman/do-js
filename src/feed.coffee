# coffee:  publish a sequence of test payloads
#
# usage: start feed --signal <signal> --test <testfile> [--op <op>]  [--track <track>] [-v] [--iter <iter>] [--maxLoss <maxLoss>]
# secondary options: [--xsignal <signalX>]

semver = '0.1.1'                  # Semantic versioning: see semver.org

_ = require 'underscore'
Lazy = require 'lazy.js'
amqp = require 'amqp'
{argv} = require 'optimist'
{logger, log, trace, traceAll, error, fatal} = require './log'

# Parse input arguments, set up log
name    = "sling"
signal = argv.signal          or fatal 'must specify signal'

# Set up AMQP Exchanges
host    = argv.host            or 'localhost'
vhost   = argv.vhost           or "v#{semver}"
xsignal = argv.xsignal         or 'signalX'
id = argv.id                   or Date.now()
iter = argv.iter               or 1
track = argv.track             or fatal "must specify a track"
maxLoss = argv.maxLoss         or 1000000
# Init log
logger argv, "#{name}: "

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

        genLoss(iter).each (payload) ->
          trace payload
          # sling the transformed test payload
          newmsg = JSON.stringify {
            ver: semver
            id: id++
            trackIds: [argv.track]
            payload: payload
          }
          # signal completion
          signalX.publish signal, newmsg
#    process.exit 0
  catch e
    fatal e


# sling:  publish a test payload
#
# usage: start sling --signal <signal> --test <testfile> [--op <op>]  [--track <track>] [-v]
# secondary options: [--xsignal <signalX>]

semver = '0.1.1'                  # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'
{argv} = require 'optimist'
{load} = require './loader'
{logger, log, trace, traceAll, error, fatal} = require './log'

# Parse input arguments, set up log
name    = "sling"
signal = argv.signal          or fatal 'must specify signal'

# Set up AMQP Exchanges
host    = argv.host            or 'localhost'
vhost   = argv.vhost           or "v#{semver}"
xsignal = argv.xsignal         or 'signalX'
id = argv.id                   or Date.now()
# Init log
logger argv, "#{name}: "

fatal "must specify test file" unless argv.test
test = require './test'
payloads = test.init argv
transform = load argv
payload = transform payloads

connection = amqp.createConnection( { host, vhost  } )

connection.on 'ready', =>
  try
    trace "connected to amqp on #{host}"
    signalX = connection.exchange xsignal, options = {
      type: 'topic'
      autodelete: false }, ->
        trace "exchange #{xsignal} ok"

        # sling the transformed test payload
        newmsg = JSON.stringify {
          ver: semver
          id: id
          trackIds: [argv.track]
          payload: payload
        }
        # signal completion
        signalX.publish signal, newmsg
        log "Signalled #{signal}"
        process.exit 0
  catch e
    fatal e

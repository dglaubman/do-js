# sling:  publish a test payload
#
# usage: start sling --name <signalnamed> --cmd <cmd> --test <testfile> --pid <pid> [-v]
# secondary options: [--xsignal=] [--xserver=]

semver = "0.1.1"                  # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'
{argv} = require 'optimist'
{bumpLoad,  heartbeat} = require './heartbeat'
{load} = require './loader'
{logger, log, trace, error, fatal} = require './log'

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  log " ... stopping"
  process.exit 0

# Parse input arguments, set up log
name = "sling"
signalQ = argv.signal
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
host = argv.host                   or 'localhost'
logger argv, "#{pname}: "

# Set up AMQP Exchanges
xsignal = argv.xsignal             or 'signalX'
xserver = argv.xserver             or 'servers'

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )


connection.on 'ready', =>
  try
    trace "connected to amqp on #{host}"
    signalX = connection.exchange xsignal, options = {
      type: 'topic'
      autodelete: false }, ->  log "exchange '#{xsignal}' ok"

# Send status/load to server status topic at regular intervals
#  heartbeat connection, xserver, 'engine.ready', pname

    fatal "must specify test file" unless argv.test
    test = require './test'
    payloads = test.init argv
    transform = load argv

    # transform the test payloads
    newmsg = JSON.stringify {
      ver: semver
      id: argv.id
      rakIds: [argv.rak]
      payload: transform payloads
    }
    # signal completion
    signalX.publish signalQ, newmsg
  catch e
    fatal e

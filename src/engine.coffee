# engine:  pop workQ, do work, signal completion, repeat
#
# usage: start engine --cmd <cmd> --name <name> --pid <pid> [-v] [-d [level]]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]

semver = "0.1.1"                  # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'
{argv} = require 'optimist'
{sendStatistic, heartbeat} = require './heartbeat'
{load} = require './loader'
{logger, log, trace, traceAll, error, fatal} = require './log'
{encode, decode} = require './util'

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  log " ... stopping"
  process.exit 0

# Parse input arguments, set up log
name = argv.name or fatal 'No process name specified'
routingKey = argv.routingKey or fatal 'No routing key specified'
track = argv.track                 or fatal 'No track specified'
signalQ = decode name
workQ = "#{signalQ}.#{track}"
pid = argv.pid                     or 0
pname = "#{decode name}/#{pid}"
host = argv.host                   or 'localhost'
vhost = argv.vhost                 or "v#{semver}"
logger argv, "#{pname}: "

# Say hello
log "starting '#{argv.op}' engine"

# Set up AMQP Exchanges
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'signalX'
xserver = argv.xserver             or 'serverX'
connection = amqp.createConnection { host: host, vhost: vhost }

# dynamically load transform
transform = load argv

#
if argv.test
  test = require './test'
  payloads = test.init argv
  test.run transform, payloads

connection.on 'ready', =>
  traceAll "connected to amqp on #{host}"
  signalX = connection.exchange xsignal, options = {
    type: 'topic'
    autodelete: false },
    ->  traceAll "exchange '#{xsignal}' ok"

  workX = connection.exchange xwork, options = { type: 'direct'},
    -> traceAll "exchange '#{xwork}' ok"

  # Send status/load to server status topic at regular intervals
  # Send loss statistic (sum of losses) to server status topic
  heartbeat connection, xserver, routingKey, track, name

  connection.queue workQ, (q) ->   # use workQ, not '' since want to share work
    #trace "started"
    q.on 'error', (e) -> log "got an error: #{e}"
    q.on 'queueBindOk', ->
      # trace "#{workQ} bound ok"
      # listen on workQ queue, simulate work/load, signal result
      q.subscribe (message, headers, deliveryInfo) ->
        work JSON.parse message.data
    q.bind(workX, workQ)

  # do work
  try
    work = (msg) ->
      payload = transform msg.payloads
      newmsg = JSON.stringify {
        ver: semver
        id: msg.id
        trackIds: msg.trackIds
        payload: payload
      }
      sendStatistic(_.reduce payload, ((loss, d) -> loss + d.loss), 0)
      # signal completion
      signalX.publish signalQ, newmsg
      trace "Signaled: #{newmsg}"
  catch e
    error e

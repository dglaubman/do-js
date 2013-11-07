# scale:  pop workQ, group input, signal completion
#
# usage: start group --name=positionName --pid= [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'
{argv} = require 'optimist'
{bumpLoad,  heartbeat} = require './heartbeat'
logger = require './log'

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  logger.log " ... stopping"
  process.exit 0

# Parse input arguments, set up log
logger.verbose = argv.v
name = argv.name or fatal( "No process name specified" )
signalQ = workQ = name
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
logger.prefix = "#{pname}: "
host = argv.host                   or 'localhost'

# Exchange names
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'exposures'
xserver = argv.xserver             or 'servers'
connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

group = (losses) ->
  _.reduce losses, (acc, bucket) ->
    acc.loss += bucket.loss
    acc

payloads = ({src: {loss: n, event: 1},status: 0} for n in [ 1..10000 ]by 1000)
logger.inspect payloads
losses = _.map payloads, (payload) -> payload.src
logger.inspect losses

logger.inspect group losses

connection.on 'ready', =>
#  logger.log "connected to amqp on #{host}"
  signalX = connection.exchange xsignal, options = {
    type: 'topic'
    autodelete: false },
    ->  # logger.log "exchange '#{xsignal}' ok"

  workX = connection.exchange xwork, options = { type: 'direct'},
    -> # logger.log "exchange '#{xwork}' ok"

  # Send status/load to server status topic at regular intervals
  heartbeat connection, xserver, 'engine.ready', pname

  connection.queue workQ, (q) ->   # use workQ, not '' since want to share work
    logger.log "started"
    q.on 'error', error
    q.on 'queueBindOk', ->
      # logger.log "'#{workQ}' bound ok"
      # listen on workQ queue, simulate work/load, signal result
      q.subscribe (message, headers, deliveryInfo) ->
        signal message.data
    q.bind(workX, workQ)

  # signal completion
  signal = (rawmsg) ->
    msg = JSON.parse rawmsg
    #logger.log "triggered by: #{rawmsg}"
    newmsg = JSON.stringify {
      ver: semver
      id: msg.id
      rakIds: msg.rakIds.slice 0
      payload:
       src: group (_.map msg.payloads, (payload) -> payload.src)
       status: status
    }
    signalX.publish signalQ, newmsg
    logger.log "Signaled: #{newmsg}"


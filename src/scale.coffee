# scale:  pop workQ, scale input by factor, signal completion
#
# usage: start scale --name=positionName [--factor <factor>] [--invert]--pid= [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require('amqp')
argv = require('optimist').argv
{bumpLoad,  heartbeat} = require('./heartbeat')
logger = require('./log')
{construct} = require('./util')
util = require 'util'
_ = require 'underscore'

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
factor = argv.factor or 1
invert = argv.invert or false
factor = if invert then -1 * factor else factor
name = argv.name or fatal( "No process name specified" )
signalQ = workQ = name
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
logger.prefix = "#{pname}: "
host = argv.host                   or 'localhost'

logger.log "Scale by factor: #{factor}"

# Exchange names
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'exposures'
xserver = argv.xserver             or 'servers'
connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

scale = (loss) ->
   _.map( loss, (v,k) ->
    if k.toUpperCase() is "LOSS"
      logger.log "(k,v): #{k}, #{v * factor}"
      construct k, [v * factor]
    else
      logger.log "(k,v): #{k}, #{v}"
      construct k, [v] )

logger.log util.inspect (_.object scale {'loss': 100, event: 1}), false, null

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
       src: scale msg.payloads[0].src
       status: status
    }
    signalX.publish signalQ, newmsg
    logger.log "Signaled: #{newmsg}"


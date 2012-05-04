# edsadapter:  pop workQ, simulate workload, signal completion
#
# usage: start edsadapter --name= --pid= [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require('amqp')
argv = require('optimist').argv
{bumpLoad,  heartbeat} = require('./heartbeat')
logger = require('./log')

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
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

xeds = 'ExposureXChange'
edsQ = 'RiskItemsPutQueue'

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

connection.on 'ready', =>
#  logger.log "connected to amqp on #{host}"
  signalX = connection.exchange xsignal, options = {
    type: 'topic'
    autodelete: false },
    ->  # logger.log "exchange '#{xsignal}' ok"

  workX = connection.exchange xwork, options = { type: 'direct'},
    -> # logger.log "exchange '#{xwork}' ok"

  edsX = connection.exchange xeds, options = { type: 'topic' },
    -> logger.log "exchange '#{xeds}' ok"

  # Send status/load to server status topic at regular intervals
  heartbeat connection, xserver, 'engine.ready', pname

  connection.queue workQ, (q) ->   # use workQ, not '' since want to share work
    logger.log "started"
    q.on 'error', error
    q.on 'queueBindOk', ->
      q.subscribe (message, headers, deliveryInfo) ->
        signal message.data, headers
    q.bind(workX, workQ)

  # signal completion
  signal = (rawmsg, headers) ->

    msg = JSON.parse rawmsg
    #logger.log "triggered by: #{rawmsg}"
    edsX.publish edsQ, msg, { headers: headers }

    newmsg = JSON.stringify {
      ver: semver
      id: msg.id
      rakIds: msg.rakIds.slice 0
      payload:
       src: msg.payloads[0].src
       status: "Called Put on Eds RiskItems"
    }
    signalX.publish signalQ, newmsg
    logger.log "Signaled: #{newmsg}"


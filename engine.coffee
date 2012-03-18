# engine:  pop workQ, simulate workload, signal completion
#
# usage: start engine --name= --pid [--workQ=] [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.0"                  # Semantic versioning: see semver.org

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
name = argv.name                   or fatal( "No process name specified" )
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
logger.prefix = "#{pname}: "
host = argv.host                   or 'localhost'

signalQ = argv.signal              or name
workQ = argv.workQ                 or name
# Exchange names
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'exposures'
xserver = argv.xserver             or 'servers'


connection = amqp.createConnection( { host: host } )
logger.log "#{pname} starting on #{host}"

connection.on 'ready', =>
  logger.log 'connection ok'
  signalX = connection.exchange xsignal, options = {
    type: 'topic'
    autodelete: false },
    -> logger.log "exchange '#{xsignal}' ok"

  workX = connection.exchange xwork, options = { type: 'direct'},
    -> logger.log "exchange '#{xwork}' ok"

  # Send status/load to server status topic at regular intervals
  heartbeat connection, xserver, 'engine.ready', pname

  connection.queue workQ, (q) ->   # use workQ, not '' since want to share work
    logger.log "#{workQ} opened ok"
    q.on 'error', error
    q.on 'queueBindOk', ->
      logger.log "'#{workQ}' bound ok"
      # listen on workQ queue, simulate work/load, signal result
      q.subscribe (message, headers, deliveryInfo) ->
        signal deliverInfo.routingKey, message.data
    q.bind(workX, workQ)

  # signal completion
  signal = (msg) ->
    e = name.slice(-1) is 'e' ? 'e' : ''
    status = "#{name}#{e}d!"
    newmsg =
      ver: semver
      id: msg.id
      rakIds: msg.rakIds.slice 0
      payload:
       src: msg.payloads[0].src
       status: status
    setTimeout ( -> signalX.publish signalQ, newmsg), 3000

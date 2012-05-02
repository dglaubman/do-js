semver = "0.1.1"

{argv} = require('optimist')
{heartbeat} = require('./heartbeat')
{config} = require('./config')
{inserter} = require('./inserter')
amqp = require('amqp')
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
logger.log "eventlog: version #{semver}"

pid = argv.pid    or 0
name = argv.name  or 'eventLog'
pname = "#{name}/#{pid}"

# AMQP config
host  = argv.host  or 'localhost'
vhost = argv.vhost or config.virtualhost
logger.log "host: #{host}, vhost: #{vhost}"

xsignal = argv.xsignal or config.signalX
xserver = argv.xserver or config.serverX


# MongoDB config
inserter.name       = argv.db         if argv.db
inserter.host       = argv.dbhost     if argv.dbhost
inserter.port       = argv.dbport     if argv.dbport
inserter.collection = argv.collection if argv.collection

connection = amqp.createConnection( { host: host, vhost: vhost } )
connection.on 'ready', ->
  signalX = connection.exchange xsignal, options =
    type: 'topic'
    autodelete: false

  heartbeat connection, xserver, 'journal.ready', pname

  # listen on signals, log to db
  connection.queue '', {exclusive: true}, (q) ->
    q.on 'error', error
    q.on 'queueBindOk', =>
      q.subscribe (message, headers, deliveryInfo) ->
        inserter.insert
          signal: deliveryInfo.routingKey
          ts: new Date().getTime()
          entry: JSON.parse message.data
    q.bind(signalX, "*")
    logger.log "listening on #{xsignal}"

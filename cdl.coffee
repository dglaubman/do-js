amqp = require('amqp')
argv = require('optimist').argv
{setLoad, loads, heartbeat} = require('./heartbeat')
logger = require('./log')

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

pname = argv.pname
logger.verbose = argv.v
logger.prefix = "#{pname}: "
host = argv.host || 'localhost'

errorHandler = (err) -> logger.log err

connection = amqp.createConnection( { host: host } )
logger.log "#{pname} starting on #{host}"

connection.on 'ready', =>
  logger.log 'connection ok'

  workX = connection.exchange 'workX', options = { type: 'direct'}, ->
    logger.log "exchange 'workX' ok"

  exposureX = connection.exchange 'exposures', options = { type: 'topic', autodelete: false },
    ->  logger.log "exchange 'exposures' ok"

  # Send ready status and current load to cdlserver.ready topic at regular intervals
  heartbeat connection, 'cdlserver.ready', pname

  connection.queue 'compileQ', (compileQ) ->
    logger.log "compileQ opened ok"
    compileQ.on 'error', errorHandler
    compileQ.on 'queueBindOk', ->
      logger.log "queue 'compileQ' bound ok"
      compileQ.subscribe (message, headers, deliveryInfo) ->
        logger.log "compileQ > #{message.data}"
        setLoad loads.H
        exposureX.publish 'cdl.ready', message.data
        logger.log "cdl.ready < #{message.data}"
    compileQ.bind(workX, "compile" )



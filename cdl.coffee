amqp = require('amqp')
logger = require('./log')
argv = require('optimist').argv
{loads, heartbeat} = require('./heartbeat')

process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

logger.verbose = argv.v
host = argv.host || 'localhost'
pname = argv.pname

errorHandler = (err) -> logger.log err

connection = amqp.createConnection( { host: host } )
logger.log "#{pname} starting on #{host}"

# Listen for all messages sent on 'edm' topic
connection.on 'ready', =>
  logger.log 'connection ok'

  workX = connection.exchange 'workX', options = { type: 'direct'}, ->
    logger.log "exchange 'workX' ok"

  exposureX = connection.exchange 'exposures', options = { type: 'topic', autodelete: false },
    ->  logger.log "exchange 'exposures' ok"

  heartbeat connection, 'cdlserver.ready', pname

  connection.queue 'compileQ', (compileQ) ->
    logger.log "compileQ opened"
    compileQ.on 'error', errorHandler
    compileQ.on 'queueBindOk', ->
      logger.log "about to listen on compileQ"
      compileQ.on 'basicQosOk',
        -> logger.log "listening to compileQ..."
      compileQ.subscribe (message, headers, deliveryInfo) ->
        logger.log "rec'd from compileQ: #{message.data},  deliveryInfo: #{deliveryInfo}"
        logger.log "... working"
        exposureX.publish 'cdl.ready', message.data
        logger.log "published availability to cdl.ready"
    logger.log "about to bind to compileQ"
    compileQ.bind(workX, "compile" )



amqp = require('amqp')
argv = require('optimist').argv
{loads, heartbeat} = require('./heartbeat')
logger = require('./log')

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
connection.on 'ready', ->
  logger.log 'connection ok'

  workX = connection.exchange 'workX', options = { type: 'direct'},
    ->  logger.log "exchange 'workX' ok"
  exposureX = connection.exchange 'exposures', options = { type: 'topic', autodelete: false },
    ->  logger.log "exchange 'exposures' ok"
  heartbeat connection, 'broker.ready', pname

  connection.queue '', {exclusive: true}, (edmQ) ->
    logger.log "temp edmQ opened"
    edmQ.on 'error', errorHandler
    edmQ.on 'queueBindOk', ->
      logger.log "exposures->edm bind ok"
      logger.log "about to subscribe"
      edmQ.subscribe (message, headers, deliveryInfo) ->
        logger.log "rec'd from exposures.edm: #{message.data},  deliveryInfo: #{deliveryInfo}"
        logger.log "sending to compile q"
        workX.publish 'compile', message.data
      edmQ.on 'basicQosOk',
        -> logger.log "subscribe to edm topic ok"
    logger.log "about to bind"
    edmQ.bind(exposureX, "edm.ready" )



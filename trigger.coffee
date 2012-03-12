amqp = require('amqp')
argv = require('optimist').argv
heartbeat = require('./heartbeat').heartbeat
logger = require('./log')

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

logger.verbose = argv.v
host = argv.host || 'localhost'
pname = argv.pname
logger.prefix = "#{pname}: "

errorHandler = (err) -> logger.log err

logger.log "#{pname} starting on #{host}"
connection = amqp.createConnection( { host: host } )
connection.on 'ready', ->
  logger.log 'connection ok'

  workX = connection.exchange 'workX', options = { type: 'direct'},
    ->  logger.log "exchange 'workX' ok"
  exposureX = connection.exchange 'exposures', options = { type: 'topic', autodelete: false },
    ->  logger.log "exchange 'exposures' ok"

  # Send ready status and current load to trigger.ready topic at regular intervals
  heartbeat connection, 'trigger.ready', pname

  # listen on 'edm.ready' topic, funnel request to 'compile' work-queue.
  connection.queue '', {exclusive: true}, (edmQ) ->
    edmQ.on 'error', errorHandler
    edmQ.on 'queueBindOk', ->
      logger.log "exposures->edm bind ok"
      edmQ.subscribe (message, headers, deliveryInfo) ->
        logger.log "#{deliveryInfo.routingKey} > #{message.data}"
        workX.publish 'compile', message.data
        logger.log "compileQ < #{message.data}"
    edmQ.bind(exposureX, "edm.ready" )



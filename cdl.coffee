amqp = require('amqp')
argv = require('optimist').argv
{bumpLoad,  heartbeat} = require('./heartbeat')
{sizes, pack, unpack} = require('./workmsg')
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

cdlCache = {}

connection.on 'ready', =>
  logger.log 'connection ok'
  exposureX = connection.exchange 'exposures', options = { type: 'topic', autodelete: false },
    -> logger.log "exchange 'exposures' ok"

  workX = connection.exchange 'workX', options = { type: 'direct'},
    -> logger.log "exchange 'workX' ok"

  # Send ready status and current load to cdlserver.ready topic at regular intervals
  heartbeat connection, 'cdlserver.ready', pname

  connection.queue 'compileQ', (compileQ) ->
    logger.log "compileQ opened ok"
    compileQ.on 'error', errorHandler
    compileQ.on 'queueBindOk', ->
      logger.log "queue 'compileQ' bound ok"
      # listen on compile queue, simulate work/load, publish result to cdl.ready
      compileQ.subscribe (message, headers, deliveryInfo) ->
        logger.log "compileQ > #{message.data}"
        [name, ver, size, src] = unpack message.data
        simulate name, ver, size, (name, ver, size) ->
          entry = cdlCache[name] ?= {}
          output = pack( name, ver, size, pname )
          entry[ver] = output
          exposureX.publish 'cdl.ready', output
          logger.log "cdl.ready < #{output}"
    compileQ.bind(workX, "compile" )

  # listen on 'cdl.ready' topic, replicate
  connection.queue '', {exclusive: true}, (cdlQ) ->
    cdlQ.on 'error', errorHandler
    cdlQ.on 'queueBindOk', ->
      logger.log "exposures->cdl bind ok"
      cdlQ.subscribe (message, headers, deliveryInfo) ->
          logger.log "cdl.ready > #{message.data}"
          [name, ver, size, src] = unpack message.data
          portfolio = cdlCache[name] ? {}
          if not portfolio[ver]
            output = pack( name, ver, size, pname )
            portfolio[ver] = output
            cdlCache[name] = portfolio
            exposureX.publish 'cdl.ready', output
            logger.log "cdl.ready < #{output} (replicated from #{src})"
    cdlQ.bind(exposureX, "cdl.ready" )



work = (n) ->
 i = 0
 while i < n * 10000000
   i++
 i
simulate = (name, ver, size, cb) ->
  timeout = 3000
#  logger.log "#{name} #{ver} #{size}"
  switch size
    when sizes.Small
      bumpLoad 3
      setTimeout ( ->
        cb name, ver, size
        bumpLoad  -3
      ), timeout
      work 3

    when sizes.Medium
      bumpLoad +10
      setTimeout ( ->
        bumpLoad -5
        setTimeout ( ->
          cb name, ver, size
          bumpLoad -5
        ), timeout
      ), timeout
      work 10

    when sizes.Large
      bumpLoad +30
      setTimeout ( ->
        bumpLoad -10
        setTimeout ( ->
          bumpLoad -10
          setTimeout ( ->
            cb name, ver, size
            bumpLoad -10
          ), timeout
        ), timeout
      ), timeout
      work 30

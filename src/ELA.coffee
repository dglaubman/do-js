# geodot: start and stop servers per commands on exec queue
#
# usage: coffee geodot [-v] [--suffix=]

semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require('amqp')
logger = require('./log')
argv = require('optimist').argv

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

host = argv.host     or 'localhost'
suffix = argv.suffix or ''
execQName = 'execQ'
execX = 'workX'
logger.verbose = argv.v
logger.log "geodot: version #{semver} starting on #{host} (vhost is v#{semver})"

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

# publish message to start geodot
connection.on 'ready', ->
  logger.log 'start ready'
  ex = connection.exchange execX, options = { type: 'direct'}
  logger.log 'publish'
  c1 = 'start trigger Geocode 1 Geocode.start'
  c2 = 'start trigger DLMIterator 1 Geocode.complete'
  c3 = 'start trigger LAMerge 1 DLMIterator.complete'
  ex.publish(execQName, c1)
  ex.publish(execQName, c2)
  ex.publish(execQName, c3)
  c4 = 'start trigger DLM 2 DLM.start'
  c5 = 'start trigger LA 2 DLM.complete'
  ex.publish(execQName, c4)
  ex.publish(execQName, c5)

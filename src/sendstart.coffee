# geodot: start and stop servers per commands on exec queue
#
# usage: coffee geodot [-v] [--suffix=]

semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require('amqp')
fs = require('fs')
logger = require('./log')
argv = require('optimist').argv

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

host = argv.host     or 'localhost'
suffix = argv.suffix or ''
execQName = 'Geocode.start'
execX = 'signalX'
logger.verbose = argv.v
logger.log "geodot: version #{semver} starting on #{host} (vhost is v#{semver})"

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

# publish message to start geodot
connection.on 'ready', ->
  logger.log 'start ready'
  ex = connection.exchange execX, options = {type: 'topic', autodelete: false}
  logger.log 'publish'
  c1 = fs.readFileSync('start.json').toString()
  ex.publish(execQName, c1)

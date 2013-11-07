# start_do: start triggers and engines from command file
#
# usage: coffee start_do [-v] [--suffix=]

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
execQName = 'execQ'
execX = 'signalX'
logger.verbose = argv.v
fname = argv.fname or 'start.json'
logger.log "dot: version #{semver} starting on #{host} (vhost is v#{semver})"

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

# publish message to start the dot
connection.on 'ready', ->
  logger.log 'start ready'
  ex = connection.exchange execX, options = {type: 'topic', autodelete: false}
  logger.log "Starting DO from #{fname}"
  cmds = fs.readFileSync(fname).toString()
  ex.publish execQName, cmds

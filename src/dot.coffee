# dot: send commands to exec queue
#

usage = "usage: coffee dot.coffee --cmdFile <cmdFile> [-v] [--host <host>] [--vhost <vhost>] [--suffix <suffix>]"

semver = "0.1.1"                  # Semantic versioning: see semver.org

require 'underscore'
amqp = require 'amqp'
fs = require 'fs'
{argv} = require 'optimist'
{logger, fatal, error, log, trace} = require('./log')

host = argv.host     or 'localhost'
vhost = argv.vhost or "v#{semver}"
suffix = argv.suffix or ''
execQName = 'execQ'
execX = 'workX'

logger argv, "dot: "
log "version #{semver} on #{host} (vhost is v#{semver})"
cmdFile = argv.cmdFile or fatal usage
cmds = fs.readFileSync( cmdFile ).toString().split /\r?\n/
rak = argv.rak or 1

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

# publish message to start dot
connection.on 'ready', ->
  trace "  connected to #{host}"
  ex = connection.exchange execX, options = { type: 'direct'}, ->
    trace "  opened exchange #{execX}"
    for cmd in cmds
      ex.publish execQName, "#{cmd} #{rak}"
      trace "    sending: #{cmd} on rak #{rak}"
    process.exit 0

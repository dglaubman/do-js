# dot: send commands to exec queue.  When done, publish dot.ready message to server exchange.
#

usage = "usage: coffee dot.coffee --cmdFile <cmdFile> --sender <sender> [-v] [--host <host>] [--vhost <vhost>] [--suffix <suffix>]"

semver = "0.1.1"                  # Semantic versioning: see semver.org

require 'underscore'
amqp = require 'amqp'
fs = require 'fs'
{argv} = require 'optimist'
{logger, fatal, error, log, trace} = require('./log')

# If parent says so, exit
process.stdin.resume()

logger argv, "dot: "

host = argv.host     or 'localhost'
vhost = argv.vhost or "v#{semver}"
log " on #{host} (vhost is #{vhost})"

suffix = argv.suffix or ''
sender = argv.sender or fatal 'must specify a sender id'
name = argv.name or fatal 'must specify a DO template name'

cmdFile = argv.cmdFile or fatal usage
cmds = fs.readFileSync( cmdFile ).toString().split /\r?\n/

rak = argv.rak or 1

execQName = 'execQ'
execX = 'workX'
serverX = 'serverX'

connection = amqp.createConnection( { host: host, vhost: vhost } )

# publish message to start dot
connection.on 'ready', ->
  trace "  connected to #{host}"
  ex = connection.exchange execX, options = { type: 'direct'}, ->
    trace "  opened exchange #{execX}"
    for cmd in cmds
      if cmd isnt ""
        ex.publish execQName, "#{cmd} #{rak}"
        trace "    sending: #{cmd} on rak #{rak}"
    # ex2 = connection.exchange serverX, options = { type: 'topic', autoDelete: false}, ->
    #   trace "  opened exchange #{serverX}"
    #   ex2.publish Dot.Topic,
    process.exit 0



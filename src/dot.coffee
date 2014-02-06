# dot: send commands to exec queue.  When done, publish dot.ready message to server exchange.
#

usage = "usage: coffee dot.coffee [--cmdFile <cmdFile> | --inline <cmds>] --routingKey <routingKey> [--track <track>] [-v] [--host <host>] [--vhost <vhost>]"

semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require 'amqp'
fs = require 'fs'
{argv} = require 'optimist'
{logger, fatal, error, log, trace} = require './log'
{deserialize} = require './util'

# If parent says so, exit
process.stdin.resume()

logger argv, "dot: "

host = argv.host     or 'localhost'
vhost = argv.vhost or "v#{semver}"
trace " on #{host} (vhost is #{vhost})"

routingKey = argv.routingKey or fatal 'must specify a routingKey'

inline = argv.inline
if not inline
  cmdFile = argv.cmdFile or fatal  "must specify either a cmdfile or inline cmds:\n #{usage}"
  cmds = fs.readFileSync( cmdFile ).toString().split /\r?\n/
else
  cmds = deserialize inline

track = argv.track or 1

execQName = 'execQ'
execX = 'workX'
serverX = 'serverX'

connection = amqp.createConnection( { host: host, vhost: vhost } )

# publish message to start dot
connection.on 'ready', ->
  try
    trace "  connected to #{host}"
    ex = connection.exchange execX, options = { type: 'direct'}, ->
      trace "  opened exchange #{execX}"
      for cmd in cmds
        if cmd isnt ""
          msg = "#{routingKey} #{track} #{cmd}"
          ex.publish execQName, msg
          trace "    sending: #{msg}"
      process.exit 0
  catch e
    error e


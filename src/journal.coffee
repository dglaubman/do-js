# journal: listen on all signals, write them to journal db
#
# usage: coffee journal [ -v ] [ --pid NUM ] [ --name ALPHANUM ]  [ AMQP-CONFIG ] [ MONGO-CONFIG ]
#  See code below for AMQP-CONFIG and MONGO-CONFIG optional settings.
semver = "0.1.1"

amqp = require('amqp')
{logger, log, trace, error, fatal} = require './log'
{argv} = require('optimist')
{heartbeat} = require('./heartbeat')
{config} = require('./config')
{store} = require('./store')

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

# Parse input arguments, set up log
pid = argv.pid    or 0
name = argv.name  or 'journal'
pname = "#{name}/#{pid}"
logger argv, "#{pname}: "

# AMQP config
host  = argv.host  or 'localhost'
vhost = argv.vhost or config.virtualhost

xsignal = argv.xsignal or config.signalX
xserver = argv.xserver or config.serverX

# init journal storage provider
write = store.init argv
#write {'signal': 99, 'ts':2, 'entry':3 }

connection = amqp.createConnection( { host: host, vhost: vhost } )
connection.on 'ready', ->
  trace "connected to #{host}/#{vhost}"
  signalX = connection.exchange xsignal, options =
    type: 'topic'
    autoDelete: false

#  heartbeat connection, xserver, 'journal.ready', pname

  # listen on signals, log to db
  connection.queue 'journo', {exclusive: true}, (q) ->
    try
      trace "queue create ok: #{q.name}"
      q.on 'error', error
      q.on 'queueBindOk', =>
        trace "queueBindOk"
        q.subscribe (message, headers, deliveryInfo) ->
          trace "recd msg: #{deliveryInfo.routingKey}"
          write {
            signal: deliveryInfo.routingKey
            ts: Date.now()
            entry: message.data.toString()
          }
      q.bind(signalX, "#")
      log "listening on #{xsignal}"
    catch e
      log e

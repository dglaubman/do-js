# trigger: when correlated signals arrive, concatenate payloads and send to workQ
#
# usage: start trigger --name= --pid= [-v] [--signals=..,..]  [--workQ=]  [--rak=]
#   secondary options:  [--xwork=work exchange] [--xsignal=signals exchange] [--xserver= server exchange]
#

semver = "0.1.1"              # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'

{argv} = require 'optimist'
{heartbeat} = require './heartbeat'
{logger, log, trace, traceAll, error, fatal} = require './log'
{encode, decode} = require './util'

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

name = argv.name                   or fatal( "No process name specified" )
pid = argv.pid                     or 0
host = argv.host                   or 'localhost'
xwork = argv.xwork                 or 'workX'        # pre v0.1.0 default
xsignal = argv.xsignal             or 'exposures'    # pre v0.1.0 default
xserver = argv.xserver             or "servers"      # pre v0.1.0 default
fatal "must specify signals to listen on" unless argv.signals

signals = _.map argv.signals.split(','), decode
rak = argv.rak
workQ = decode name
pname = "#{decode name}/#{pid}"
logger argv, "Trigger #{pname}: "

log "#{decode signals} -> #{decode name}"

filter = {  'signals': (signals), id: rak }

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

connection.on 'ready', ->

  workX = connection.exchange xwork, options = { type: 'direct'},
    ->  traceAll "exchange #{xwork} ok"
  signalX = connection.exchange xsignal, options = { type: 'topic', autodelete: false },
    ->  traceAll "exchange #{xsignal} ok"

  # Send ready status to trigger.ready topic at regular intervals
  heartbeat connection, xserver, 'trigger.ready', pname

  # when correlated signals arrive, concatenate payloads and funnel request to work queue.
  trigger = (signal, raw) ->
    traceAll "#{signal} > #{raw}"
    data = JSON.parse raw
    switch data.ver or 0
      when 0                                       # pre v0.1.0 default
        workX.publish workQ, data
      when semver
        if (m = build( signal, data ))
          workX.publish( workQ, m )
          traceAll "publish on #{workQ}"
      else
        error "expected version #{semver}, got #{data.ver}"

  # listen on signals, fire trigger
  connection.queue '', {exclusive: true}, (q) ->
    traceAll "binding queue to keys: #{signals}"
    q.on 'error', error
    q.on 'queueBindOk', ->
      traceAll "queue bind ok"
      q.subscribe (message, headers, deliveryInfo) ->
        trace "recd message from: #{deliveryInfo.routingKey}"
        trigger deliveryInfo.routingKey, message.data
    q.bind(signalX, signal) for signal in signals
    trace "listening on #{filter.signals} (rak #{filter.id})"

  cache = {}
  build =  (signal, msg ) ->
    return null if msg.ver isnt semver
    return null unless (filter.id in msg.rakIds)
    if signal in filter.signals
      entry = cache[ msg.id ] or= {
        remaining: filter.signals
        rakIds: msg.rakIds
        payloads: []
        }
      entry.payloads.push msg.payload
      entry.remaining = _.without( entry.remaining, signal )
      return null if not _.isEmpty( entry.remaining )
      m = JSON.stringify(
        ver: semver
        rakIds: _.union( entry.rakIds, msg.rakIds )
        id: msg.id
        payloads: entry.payloads
        )
      trace "triggering: #{m}"
      delete cache[msg.id]
      m

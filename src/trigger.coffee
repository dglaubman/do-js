# trigger: when correlated signals arrive, concatenate payloads and send to workQ
#
# usage: start trigger --name <name> --signals <signals>  --track <track>
#           --xwork <workX> --xsignal <signalX> [-v] [--pid <pid>]

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
vhost = argv.vhost                 or "v#{semver}"
xwork = argv.xwork                 or fatal 'Specify a work exchange'
xsignal = argv.xsignal             or fatal 'Specify a signal exchange'
fatal "must specify signals to listen on" unless argv.signals

signals = _.map argv.signals.split(','), decode
track = argv.track
workQ = "#{decode name}.#{track}"
pname = "#{decode name}/#{pid}"
logger argv, "Trigger #{pname}: "

log "#{decode signals} -> #{decode name}"

filter = {  'signals': (signals), id: track }

connection = amqp.createConnection( { host: host, vhost: vhost } )

connection.on 'ready', ->

  workX = connection.exchange xwork, options = { type: 'direct'},
    ->  traceAll "exchange #{xwork} ok"
  signalX = connection.exchange xsignal, options = { type: 'topic', autodelete: false },
    ->  traceAll "exchange #{xsignal} ok"

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
    log "listening on #{filter.signals} (track #{filter.id})"

  cache = {}
  build =  (signal, msg ) ->
    return null if msg.ver isnt semver
    return null unless (filter.id in msg.trackIds)
    if signal in filter.signals
      entry = cache[ msg.id ] or= {
        remaining: filter.signals
        trackIds: msg.trackIds
        payloads: []
        }
      entry.payloads.push msg.payload
      entry.remaining = _.without( entry.remaining, signal )
      return null if not _.isEmpty( entry.remaining )
      m = JSON.stringify(
        ver: semver
        trackIds: _.union( entry.trackIds, msg.trackIds )
        id: msg.id
        payloads: entry.payloads
        )
      trace "triggering: #{m}"
      delete cache[msg.id]
      m

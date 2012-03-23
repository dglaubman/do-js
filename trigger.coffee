# trigger: when correlated signals arrive, concatenate payloads and send to workQ
#
# usage: start trigger --name= --pid= [-v] [--signals=..,..]  [--workQ=]  [--rakid=]
#   secondary options:  [--xwork=work exchange] [--xsignal=signals exchange] [--xserver= server exchange]
#

semver = "0.1.0"              # Semantic versioning: see semver.org

amqp = require('amqp')
argv = require('optimist').argv
heartbeat = require('./heartbeat').heartbeat
logger = require('./log')
_ = require('underscore')
error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

logger.verbose = argv.v
name = argv.name                   or fatal( "No process name specified" )
pid = argv.pid                     or 0
host = argv.host                   or 'localhost'
xwork = argv.xwork                 or 'workX'        # pre v0.1.0 default
xsignal = argv.xsignal             or 'exposures'    # pre v0.1.0 default
xserver = argv.xserver             or "servers"      # pre v0.1.0 default
signals = argv.signals?.split(',') or ["edm.ready"]  # pre v0.1.0 default
rakId = argv.rakid                 or ""             # pre v0.1.0 default
workQ = argv.workQ                 or "#{name}"      # by default use same name for trigger, engine, signal
pname = "#{name}/#{pid}"
logger.prefix = "Trigger #{pname}: "

filter = {  'signals': signals, id: rakId }

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

connection.on 'ready', ->

  workX = connection.exchange xwork, options = { type: 'direct'},
    ->  # logger.log "exchange '#{xwork}' ok"
  signalX = connection.exchange xsignal, options = { type: 'topic', autodelete: false },
    ->  # logger.log "exchange '#{xsignal}' ok"

  # Send ready status to trigger.ready topic at regular intervals
  heartbeat connection, xserver, 'trigger.ready', pname

  # when correlated signals arrive, concatenate payloads and funnel request to work queue.
  trigger = (signal, raw) ->
    logger.log "#{signal} > #{raw}"
    data = JSON.parse raw
    switch data.ver or 0
      when 0                                       # pre v0.1.0 default
        workX.publish workQ, data
      when semver
        workX.publish( workQ, m ) if (m = build( signal, data ))
      else
        error "expected version #{semver}, got #{data.ver}"

  # listen on signals, fire trigger
  connection.queue '', {exclusive: true}, (workQ) ->
    workQ.on 'error', error
    workQ.on 'queueBindOk', ->
      workQ.subscribe (message, headers, deliveryInfo) ->
        trigger deliveryInfo.routingKey, message.data
    workQ.bind(signalX, signal) for signal in signals
    logger.log "listening on #{filter.signals} (rak #{filter.id})"

  cache = {}
  build =  (signal, data ) ->
    return null if data.ver isnt semver
    return null unless (filter.id in data.rakIds)
    if signal in filter.signals
      entry = cache[ data.id ] or= {
        remaining: filter.signals
        rakIds: data.rakIds
        payloads: []
        }
      entry.payloads.push(data.payload)
      entry.remaining = _.without( entry.remaining, signal )
      return null if not _.isEmpty( entry.remaining )
      m = JSON.stringify(
        ver: semver
        rakIds: _.union( entry.rakIds, data.rakIds )
        id: data.id
        payloads: entry.payloads.slice 0
        )
      logger.log "triggering: #{m}"
      m

# engine:  pop workQ, simulate workload, signal completion
#
# usage: start engine --name= --pid= [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require('amqp')
argv = require('optimist').argv
{bumpLoad,  heartbeat} = require('./heartbeat')
logger = require('./log')

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  process.exit 0

# Parse input arguments, set up log
logger.verbose = argv.v
name = argv.name or fatal( "No process name specified" )
signalQ = workQ = name
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
logger.prefix = "#{pname}: "
host = argv.host                   or 'localhost'

# Exchange names
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'exposures'
xserver = argv.xserver             or 'servers'
connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

connection.on 'ready', =>
#  logger.log "connected to amqp on #{host}"
  signalX = connection.exchange xsignal, options = {
    type: 'topic'
    autodelete: false },
    ->  # logger.log "exchange '#{xsignal}' ok"

  workX = connection.exchange xwork, options = { type: 'direct'},
    -> # logger.log "exchange '#{xwork}' ok"

  # Send status/load to server status topic at regular intervals
  heartbeat connection, xserver, 'engine.ready', pname

  connection.queue workQ, (q) ->   # use workQ, not '' since want to share work
    logger.log "started"
    q.on 'error', error
    q.on 'queueBindOk', ->
      # logger.log "'#{workQ}' bound ok"
      # listen on workQ queue, simulate work/load, signal result
      q.subscribe (message, headers, deliveryInfo) ->
        signal message.data
    q.bind(workX, workQ)

  # signal completion
  signal = (rawmsg) ->
    e = if name.slice(-1) is 'e' then '' else 'e'
    status = "#{name}#{e}d!"
    msg = JSON.parse rawmsg
    #logger.log "triggered by: #{rawmsg}"
    newmsg = JSON.stringify {
      ver: semver
      id: msg.id
      rakIds: msg.rakIds.slice 0
      payload:
       src: msg.payloads[0].src
       status: status
    }
    simulate name, Sizes.Medium, (-> signalX.publish signalQ, newmsg )
    logger.log "Signaled: #{newmsg}"
work = (n) ->
 i = 0
 while i < n * 10000000
   i++
 i
Sizes = { Tiny: 1, Small: 2, Medium: 3, Large: 4, XLarge: 5 }
simulate = (name, size, cb) ->
  timeout = 1000
  switch size
    when Sizes.Tiny
      bumpLoad 1
      setTimeout ( ->
        bumpLoad  -1
        cb name, size
      ), timeout
      work 1

    when Sizes.Small
      bumpLoad 3
      setTimeout ( ->
        bumpLoad  -3
        cb name, size
      ), timeout
      work 3

    when Sizes.Medium
      bumpLoad 10
      setTimeout ( ->
        bumpLoad -5
        setTimeout ( ->
          bumpLoad -5
          cb name, size
        ), timeout
      ), timeout
      work 10

    when Sizes.Large
      bumpLoad +30
      setTimeout ( ->
        bumpLoad -10
        setTimeout ( ->
          bumpLoad -10
          setTimeout ( ->
            bumpLoad -10
            cb name, size
          ), timeout
        ), timeout
      ), timeout
      work 30

    when Sizes.XLarge
      bumpLoad +75
      setTimeout ( ->
        bumpLoad -15
        setTimeout ( ->
          bumpLoad -15
          setTimeout ( ->
            bumpLoad -15
            setTimeout ( ->
              bumpLoad -15
              setTimeout ( ->
                bumpLoad -15
                cb name, size
              ), timeout
            ), timeout
          ), timeout
        ), timeout
      ), timeout
      work 30



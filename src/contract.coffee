# contract:  compute contract payout
#
# usage: start contract --cdl <filename> --name <position> --pid <pid> [-v]
# secondary options: [--xsignal=] [--xwork=] [--xserver=]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

_ = require 'underscore'
amqp = require 'amqp'
{argv}  = require 'optimist'
{bumpLoad,  heartbeat} = require './heartbeat'
logger = require './log'
fs = require 'fs'
{visitor} = require './visitor'

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

# If parent says so, exit
process.stdin.resume()
process.stdin.on 'end', ->
  logger.log " ... stopping"
  process.exit 0

# Parse input arguments, set up log
logger.verbose = argv.v
cdl = argv.cdl

name = argv.name or fatal( "No process name specified" )
signalQ = workQ = name
pid = argv.pid                     or 0
pname = "#{name}/#{pid}"
logger.prefix = "#{pname}: "
host = argv.host                   or 'localhost'

logger.log "Pays contract layer losses"

# Exchange names
xwork = argv.xwork                 or 'workX'
xsignal = argv.xsignal             or 'exposures'
xserver = argv.xserver             or 'servers'
connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

compile = (text) ->
  pattern = ///
    ^\s*
    (\d*\.?\d*)%                      # match share amount
    \s+SHARE\s+OF\s+
    (\d*\.?\d*|UNLIMITED)             # match limit amount
    \s+XS\s+
    (\d*\.?\d*)                       # match attachment amount
    \s*$
  ///i
  [share, limit, attach] = text.match(pattern)[1..3]
  share /= 100
  if (_.isString limit) and (_.isEqual 'UNLIMITED', limit.toUpperCase())
     limit = Infinity
  (loss) ->
    share * ( Math.min limit, Math.max( 0, loss - attach ) )

text = fs.readFileSync( cdl + ".cdl" ).toString()
payout = compile text

xform = visitor payout

pay = (losses) ->
  _.map losses, (loss) ->
    _.object xform loss

losses = [ { loss: 10000, event: 1 }, { loss: 9600, event: 2} ]
logger.inspect pay losses

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
    msg = JSON.parse rawmsg
    #logger.log "triggered by: #{rawmsg}"
    newmsg = JSON.stringify {
      ver: semver
      id: msg.id
      rakIds: msg.rakIds.slice 0
      payload:
       src: scale msg.payloads[0].src
       status: status
    }
    signalX.publish signalQ, newmsg
    logger.log "Signaled: #{newmsg}"


# exec: start and stop servers per commands on git diff execexec queue
#
# usage: coffee exec [-v] [--suffix=]

semver = "0.1.0"                  # Semantic versioning: see semver.org

amqp = require('amqp')
spawn = require('child_process').spawn
logger = require('./log')
argv = require('optimist').argv

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

host = argv.host     or 'localhost'
suffix = argv.suffix or ''

logger.verbose = argv.v
logger.log "exec: version #{semver} starting on #{host}"

execQ = 'execQ' + suffix;
workX = 'workX' + suffix;
serverX = 'serverX' + suffix;
signalX = 'signalX' + suffix;

connection = amqp.createConnection( { host: host } )

# Listen for all messages sent to execQ queue
connection.on 'ready', ->
  logger.log 'exec: connection ok'
  q = connection.queue('exec')

  connection.exchange workX, options = { type: 'direct'}, ->
    logger.log "exec: exchange '#{workX}' ok"
    q.bind workX, execQ
    logger.log "exec: queue '#{execQ}' bind ok"

    procs = {}
    procNum = 0

    q.subscribe options={ack:true}, (message, headers, deliveryInfo) ->
      logger.log message.data
      [verb,type,server,rakids,signals] =  message.data.toString().split /\s+/g
      q.shift()
      switch verb
        when 'start'
          processName = "#{server}/#{procNum}"
          switch type
            when 'engine'
              spawnCmd = "coffee engine --name #{server}  --pid #{procNum} -v --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"
            when 'trigger'
              spawnCmd = "coffee trigger --name #{server}  --pid #{procNum} --rakids #{rakids} --signals #{signals}" +
                         " --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"
          logger.log spawnCmd
          proc = spawn( 'cmd', ['/s', '/c', spawnCmd ] )
          proc.on 'exit', =>
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish "#{type}.stopped", processName
              logger.log "#{server} stopped"
          proc.stderr.setEncoding 'utf8'
          proc.stderr.on 'data', (data) -> logger.log data
          proc.stdout.on 'data',  (data) -> logger.log data
          procs[processName] = proc
          procNum++

        when 'stop'
          procs[server].stdin.end()
          logger.log "stopping #{server}"



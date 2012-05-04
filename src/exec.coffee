# exec: start and stop servers per commands on exec queue
#
# usage: coffee exec [-v] [--suffix=]

semver = "0.1.1"                  # Semantic versioning: see semver.org

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
logger.log "exec: version #{semver} starting on #{host} (vhost is v#{semver})"

execQ = 'execQ' + suffix;
workX = 'workX' + suffix;
serverX = 'serverX' + suffix;
signalX = 'signalX' + suffix;
commonArgs = " -v --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"

connection = amqp.createConnection( { host: host, vhost: "v#{semver}" } )

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
      words =  message.data.toString().split /\s+/g

      q.shift()
      switch words[0]
        when 'start'
          [type,server,rakid,signals] = words.splice 1
          processName = "#{server}/#{procNum}"
          switch type
            when 'adapter'
              spawnCmd = "coffee edsadapter --name #{server}  --pid #{procNum} #{commonArgs}"
            when 'engine'
              spawnCmd = "coffee engine --name #{server}  --pid #{procNum} #{commonArgs}"
            when 'trigger'
              spawnCmd = "coffee trigger --name #{server}  --pid #{procNum} --rakid #{rakid} --signals #{signals} #{commonArgs}"
#          logger.log spawnCmd
          proc = spawn( 'cmd', ['/s', '/c', spawnCmd ] )
          proc.on 'exit', =>
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish "#{type}.stopped", processName
              logger.log "#{processName} stopped"
          proc.stderr.setEncoding 'utf8'
          proc.stderr.on 'data', (data) -> logger.log data
          proc.stdout.on 'data',  (data) -> logger.log data
          procs[processName] = proc
          procNum++

        when 'stop'
          name = words[1]
          try
            procs[name].stdin.end()
#            logger.log "exec: stopping #{name}"
          catch error
            logger.log "exec: can't stop #{name} because does not exist. Signaling #{name} stopped. "
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish "#{type}.stopped", name






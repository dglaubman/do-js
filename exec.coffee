amqp = require('amqp')
spawn = require('child_process').spawn
logger = require('./log')
argv = require('optimist').argv

logger.verbose = argv.v
host = argv.host || 'localhost'
logger.log "exec starting on #{host}"

connection = amqp.createConnection( { host: host } )

# Listen for all messages sent to 'exec' queue
connection.on 'ready', ->
  logger.log 'connection ok'
  execQ = connection.queue('exec')

  connection.exchange 'workX', options = { type: 'direct'}, ->
    logger.log "exchange 'workX' ok"
    execQ.bind('workX', 'exec')
    logger.log "queue 'exec' bind ok"

    procs = {}
    procNum = 0

    execQ.subscribe options={ack:true}, (message, headers, deliveryInfo) ->
      [verb,server] =  message.data.toString().split /\s+/g
      execQ.shift()
      switch verb
         when 'start'
           processName = "#{server}/#{procNum}"
           spawnCmd = "coffee #{server} -v --host #{host} --pname #{processName}"
           logger.log spawnCmd
           proc = spawn( 'cmd', ['/s', '/c', spawnCmd ] )
           proc.on 'exit', =>
             exchange = connection.exchange "servers", options = { type: 'topic'}, ->
               exchange.publish (if server == 'cdl' then 'cdlserver.stopped' else 'trigger.stopped'), processName
               logger.log "#{server} stopped"
           proc.stderr.setEncoding 'utf8'
           proc.stderr.on 'data', (data) -> logger.log data
           proc.stdout.on 'data',  (data) -> logger.log data
           procs[processName] = proc
           procNum++

         when 'stop'
           procs[server].stdin.end()
           logger.log "stopping #{server}"

process.on 'message', (cmdline) ->
  console.log 'Child got message: ' + cmdline
  process.exit 0



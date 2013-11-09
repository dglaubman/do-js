# exec: start and stop servers per commands on exec queue
#
# usage: coffee exec [-v] [--suffix=]
# add comment
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require 'amqp'
{spawn} = require 'child_process'
{logger, error, fatal, log, trace} = require './log'
{argv} = require 'optimist'

host = argv.host     or 'localhost'
suffix = argv.suffix or ''

logger argv, "exec: "
vhost = argv.vhost or "v#{semver}"
log "on #{host} (vhost is #{vhost})"

execQ = 'execQ' + suffix
workX = 'workX' + suffix
serverX = 'serverX' + suffix
signalX = 'signalX' + suffix
commonArgs = " -v -d --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"

connection = amqp.createConnection( { host, vhost } )

# Listen for all messages sent to execQ queue
connection.on 'ready', ->
  log 'exec: connection ok'
  q = connection.queue "", (q) ->
    trace "#{q.name} is open"

    connection.exchange workX, options = { type: 'direct'}, ->
      log "exchange '#{workX}' ok"
      q.bind workX, execQ
      log "queue '#{execQ}' bind ok"

      procs = {}
      procNum = 0

      q.subscribe options={ack:true}, (message, headers, deliveryInfo) ->
        log message.data
        words =  message.data.toString().split /\s+/g

        q.shift()
        switch words[0]
          when 'start'
            [type,server,rakid,option] = words.splice 1
            processName = "#{server}/#{procNum}"
            switch type
              when 'test'
                cmd = "engine.coffee --op scale --factor 1.0 --test #{option} --name #{server}
                  --pid #{procNum} #{commonArgs}"

              when 'trigger'
                cmd = "trigger.coffee -v  --name #{server}
                  --pid #{procNum} --rakid #{rakid} --signals #{option} #{commonArgs}"

              when 'contract'
                cmd = "engine.coffee --op contract --cdl #{option}
                  --name #{server} --pid #{procNum} --rakid #{rakid}  #{commonArgs}"

              when 'scale'
                cmd = "engine.coffee --op scale --factor #{option}
                  --name #{server}  --pid #{procNum} --rakid #{rakid} #{commonArgs}"

              when 'invert'
                cmd = "engine.coffee --op invert --name #{server}
                  --pid #{procNum} --rakid #{rakid} #{commonArgs}"

              when 'group'
                cmd = "engine.coffee --op group --name #{server}
                  --pid #{procNum} --rakid #{rakid} #{commonArgs}"

            try
              # proc = spawn 'node', ["coffee", "-v"], {PATH: "/usr/local/bin:/bin/:/mingw/bin:/cygdrive/e/src/nodejs"}
              proc = spawn( 'cmd', ['/s', '/c', 'coffee ' + cmd ] )
              proc.on 'exit', =>
                exchange = connection.exchange serverX, options = { type: 'topic'}, ->
                  exchange.publish "#{type}.stopped", processName
                  log "#{processName} stopped"
              proc.stderr.setEncoding 'utf8'
              proc.stderr.on 'data', (data) -> error "Error: #{data}"
              proc.stdout.on 'data',  (data) -> log data
              procs[processName] = proc
              procNum++
            catch  e
              error e
          when 'stop'
            name = words[1]
            try
              procs[name].stdin.end()
  #            log "exec: stopping #{name}"
            catch error
            log "exec: can't stop #{name} because does not exist. Signaling #{name} stopped. "
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish "#{type}.stopped", name

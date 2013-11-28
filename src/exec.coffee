# exec: start and stop servers per commands on exec queue
#
# usage: coffee exec [--host <host>] [--vhost <vhost>] [-v] [-d [<level>]] [--suffix <suffix>]
# add comment
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require 'amqp'
{spawn} = require 'child_process'
{logger, error, fatal, log, trace} = require './log'
{argv} = require 'optimist'

host = argv.host     or 'localhost'
suffix = argv.suffix or ''

logger argv
vhost = argv.vhost or "v#{semver}"
log "exec: on #{host} (vhost is #{vhost})"

execQ = 'execQ' + suffix
workX = 'workX' + suffix
serverX = 'serverX' + suffix
signalX = 'signalX' + suffix

verboseArg = if argv.v then "-v" else ""
traceArg = if argv.d then "-d" else ""
nodeInspectorArg = (n) ->
  return "" unless argv.n
  return "--nodejs --debug=" + (5858 + n + 1)

commonArgs = " #{traceArg} #{verboseArg} --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"

connection = amqp.createConnection( { host, vhost } )

# Listen for all messages sent to execQ queue
connection.on 'ready', ->
  trace 'exec: connection ok'
  q = connection.queue "", (q) ->
    trace "exec: #{q.name} is open"

    connection.exchange workX, options = { type: 'direct'}, ->
      trace "exec: exchange '#{workX}' ok"
      q.bind workX, execQ
      log "exec: queue '#{execQ}' bind ok"

      procs = {}
      procNum = 0

      q.subscribe options={ack:true}, (message, headers, deliveryInfo) ->
        words =  message.data.toString().split /\s+/g
        trace words

        q.shift()
        switch words[0]
          when 'start'
            [type,server,option, rak] = words.splice 1
            processName = "#{server}/#{procNum}"
            switch type
              when 'test'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op scale --factor 1.0 --test #{option} --name #{server}
                  --pid #{procNum} #{commonArgs}"

              when 'trigger'
                cmd = "#{nodeInspectorArg procNum} trigger.coffee -v  --name #{server} --signals #{option} --rak #{rak}
                  --pid #{procNum}  #{commonArgs}"

              when 'contract'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op contract --cdl #{option}
                  --name #{server} --pid #{procNum} #{commonArgs}"

              when 'scale'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op scale --factor #{option}
                  --name #{server}  --pid #{procNum} #{commonArgs}"

              when 'invert'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op invert --name #{server}
                  --pid #{procNum} #{commonArgs}"

              when 'group'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op group --name #{server}
                  --pid #{procNum} #{commonArgs}"

            try
              #proc = spawn 'coffee', cmd.split ' '
              proc = spawn( 'cmd', ['/s', '/c', 'coffee ' + cmd ] )
              proc.on 'exit', =>
                exchange = connection.exchange serverX, options = { type: 'topic'}, ->
                  exchange.publish "#{type}.stopped", processName
                  log "#{processName} stopped"
              proc.stderr.setEncoding 'utf8'
              proc.stderr.on 'data', (data) -> trace "#{processName} stderr: #{data}", -1
              proc.stdout.on 'data',  (data) -> log data
              procs[processName] = proc
              procNum++
            catch  e
              error  "#{processName}: #{e}"
          when 'stop'
            name = words[1]
            try
              procs[name].stdin.end()
              log "stopping #{name}"
            catch error
              error "can't stop #{name} because does not exist. Signaling #{name} stopped. "
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish "#{type}.stopped", name

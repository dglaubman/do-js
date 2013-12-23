# exec: start and stop servers per commands on exec queue
#
# usage: coffee exec [--host <host>] [--vhost <vhost>] [-v] [-d [<level>]] [--suffix <suffix>]
#
semver = "0.1.1"                  # Semantic versioning: see semver.org

amqp = require 'amqp'
os = require 'os'
{spawn} = require 'child_process'
{logger, error, fatal, log, trace} = require './log'
{argv} = require 'optimist'
{RouteReady, Stopped} = require './msgs'

logger argv

host = argv.host     or 'localhost'
vhost = argv.vhost or "v#{semver}"
suffix = argv.suffix or ''
globalTrack = argv.track or 0

log "exec: on #{host} (vhost is #{vhost})"

process.stdin.resume()

execQ = 'execQ' + suffix
workX = 'workX' + suffix
serverX = 'serverX' + suffix
signalX = 'signalX' + suffix

verboseArg = if argv.v then "-v" else ""
traceArg = if argv.d then "-d" else ""
nodeInspectorArg = (n) ->
  return "" unless argv.n
  return "--nodejs --debug=" + (5858 + n + 1) + " "

commonArgs = " #{traceArg} #{verboseArg} --host #{host} --xsignal #{signalX} --xwork #{workX} --xserver #{serverX}"

connection = amqp.createConnection( { host, vhost } )

# Listen for all messages sent to execQ queue
connection.on 'ready', ->
  trace 'exec: connection ok'
  connection.queue "exec." + Date.now(), (q) ->
    trace "exec: queue #{q.name} is open"

    connection.exchange workX, options = { type: 'direct'}, ->
      trace "exec: exchange #{workX} ok"
      q.bind workX, execQ
      log "exec: q->#{execQ} bind ok"

      procs = {}
      procNum = 0
      subscriptions = []

      q.subscribe options={ack:true}, (message, headers, deliveryInfo) ->
        words =  message.data.toString().split /\s+/g
        trace words

        q.shift()
        [ticket, track, verb, rest...] = words
        switch verb
          when 'start'
            [type, name, option, option2] = rest
            processName = "#{name}/#{procNum}"
            switch type
              when 'test'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op scale --factor 1.0 --test #{option} --name #{name}
                  --pid #{procNum} #{commonArgs}"

              when 'trigger'
                cmd = "#{nodeInspectorArg procNum} trigger.coffee -v   --signals #{option} --name #{name} --track #{track}
                  --pid #{procNum}  #{commonArgs}"

              when 'contract'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op contract --cdl #{option} --name #{name} --track #{track} --routingKey #{ticket}
                  --pid #{procNum} #{commonArgs}"

              when 'scale'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op scale --factor #{option} --name #{name} --track #{track} --routingKey #{ticket}
                  --pid #{procNum} #{commonArgs}"

              when 'invert'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op invert --name #{name}  --track #{track} --routingKey #{ticket}
                  --pid #{procNum} #{commonArgs}"

              when 'group'
                cmd = "#{nodeInspectorArg procNum} engine.coffee --op group --name #{name}  --track #{track} --routingKey #{ticket}
                  --pid #{procNum} #{commonArgs}"

              when 'subscription'
                dots = subscriptions[ ticket ] or= []
                track = dots[ name ]
                if not track
                  track = ++globalTrack
                  dots[ name ] = track
                  dot = name
                else
                  dot = 'nop' # if dot is already running, send nop cmdFile

                cmd = "#{nodeInspectorArg procNum} dot.coffee --cmdFile ../script/#{dot}.dot --name #{name} --track #{track} --routingKey #{ticket}
                  --pid #{procNum} #{commonArgs}"

              when 'sling'
                cmd = "#{nodeInspectorArg procNum} sling.coffee --signal #{name} --op group --test #{option} --track #{track}
                  --pid #{procNum} #{commonArgs}"

              when 'feed'
                cmd = "#{nodeInspectorArg procNum} feed.coffee --signal #{name} --maxLoss #{option} --track #{track} --iter #{option2}
                  --id #{ticket} --pid #{procNum} #{commonArgs}"

            try
              trace cmd
              if os.platform() is 'win32'
                proc = spawn( 'cmd', ['/s', '/c', 'coffee ' + cmd ] )       # Windows
              else
                proc = spawn '/usr/local/bin/coffee', cmd.trim().split ' '  # Mac, Linux

              proc.on 'exit', =>
                exchange = connection.exchange serverX, options = { type: 'topic'}, ->
                  if type is 'subscription'
                    track = subscriptions[ ticket ][name]
                    log "#{name} ready on track #{track}"
                    exchange.publish ticket, RouteReady( name, track)
                  else
                    exchange.publish ticket, Stopped( type, processName )
                    log "#{processName} stopped"
              proc.stderr.setEncoding 'utf8'
              proc.stderr.on 'data', (data) -> log "#{processName} stderr: #{data}", -1
              proc.stdout.on 'data',  (data) -> log data
              procs[processName] = proc
              procNum++
            catch  e
              error  "#{processName}: #{e}"

          when 'stop'
            [ type, name ] = rest
            try
              procs[name].stdin.end()
              log "stopping #{name}"
            catch error
              error "can't stop #{name} because does not exist. Signaling #{name} stopped. "
            exchange = connection.exchange serverX, options = { type: 'topic'}, ->
              exchange.publish ticket, Stopped(type, name)

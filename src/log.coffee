util = require('util')
root = exports ? this

prefix = ""
verbose = false
debug = false
debugLevel = 0

logger = (argv, pre) ->
  debug = argv.d
  switch typeof debug
    when 'number' then debugLevel = debug
    when 'boolean' then debugLevel = 1
  verbose = argv.v
  if pre then prefix = pre


write = (o) ->
  util.puts( "#{prefix}#{o}" )

log =  (o) ->
  write o if verbose

trace = (o, level) ->
  level or= 0
  write (util.inspect o, false, null) if debugLevel > level

error = (err) ->
  write " Error: #{err}"

fatal = (err) ->
  error err
  process.exit 0

root.logger = logger
root.log = log
root.trace = trace
root.fatal = fatal
root.error = error

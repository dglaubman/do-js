util = require('util')
root = exports ? this

prefix = ""
verbose = false
debug = false

logger = (argv, pre) ->
  debug = argv.d
  verbose = argv.v
  if pre then prefix = pre


write = (o) ->
  util.puts( "#{prefix}#{o}" )

log =  (o) ->
  write o if verbose

trace = (o) ->
  write (util.inspect o, false, null) if debug

error = (err) ->
  write err

fatal = (err) ->
  error err
  process.exit 0

root.logger = logger
root.log = log
root.trace = trace
root.fatal = fatal
root.error = error

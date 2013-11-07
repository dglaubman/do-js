util = require('util')
root = exports ? this

root.verbose = false
root.prefix = ""
root.log =  log = (o) -> (util.puts( "#{root.prefix}#{o}" ) if root.verbose)
root.inspect = inspect =  (o) ->
  log util.inspect o, false, null




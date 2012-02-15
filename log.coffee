util = require('util')
root = exports ? this

root.verbose = false
root.prefix = ""
root.log =  (o) -> (util.puts( "#{root.prefix}#{o}" ) if root.verbose) # util.inspect( o ) )



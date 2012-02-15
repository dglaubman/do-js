util = require('util')
root = exports ? this

root.verbose = false
root.log =  (o) -> (util.puts( o ) if root.verbose) # util.inspect( o ) )



root = exports ? this

{fatal} = require '../log'

root.init = (argv) ->
  fatal "#{argv.op}? This is not the module you are looking for."


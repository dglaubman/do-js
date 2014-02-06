# load: loads and initializes logic module
#
#   Returns transform which takes an array of payloads (from a workQ msg).
#   The transform returns a new payload
#
#   Modules are registered in Ops, and reside in ./modules
#   Module signature is:
#      init: argv -> payload list -> payload
#      run: payload list -> payload
#

root = exports ? this

{error} = require './log'
{Ops} = require './Ops'

root.load = (argv) ->
  module = Ops argv.op
  {run, init} = require "./module/#{module}"

  try
    init argv
  catch e
    error e

  # return transform function
  (payloads) ->
    try
      run payloads
    catch e
      error e
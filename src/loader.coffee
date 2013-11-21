# load: loads and initializes logic module
#
#   Returns function which takes an array of payloads (from a workQ msg).
#   The function maps the worker to each payload's data,
#   and returns a new payload
#       data: worker ( map payloads, payload -> payload.data )
#       trail: [ status, [ prevstatuses] ]
#
#   Modules are registered in Ops, and reside in ./modules
#   Module signature is:
#      init argv
#      worker [ {any: ignored, loss: 2400}, ... ]
#

root = exports ? this

_ = require 'underscore'
{logger, trace} = require './log'
{Ops} = require './Ops'
{Status} = require './Status'
{construct, mapcat} = require './util'

root.load = (argv) ->
  module = Ops argv.op
  {run, init} = require "./module/#{module}"
  init argv
  (payloads) ->
    trace payloads
    data = run (mapcat ((payload) -> payload.data), payloads)
    stats = mapcat ((payload) -> payload.trail), payloads
    trail = construct { op: module, status: Status.OK.name }, [stats]
    { data, trail }

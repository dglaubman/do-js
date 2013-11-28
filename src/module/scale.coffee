root = exports ? this

_ = require 'underscore'
{visit} = require '../visitor'
{trace, logger} = require '../log'

factor = 1
scale = visit (loss) -> loss * factor

root.run = (payloads) ->
  throw "scale must have a single payload" unless payloads.length is 1
  losses = payloads[0]
  _.map losses, (loss) ->
    _.object scale loss

root.init = (argv) ->
  logger argv
  factor = argv.factor

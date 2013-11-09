root = exports ? this

_ = require 'underscore'
{visit} = require '../visitor'
{trace, logger} = require '../log'

factor = 1
scale = visit (loss) -> loss * factor

root.run = (losses) ->
  trace "Scale worker: loss: "
  trace losses
  _.map losses, (loss) ->
    _.object scale loss

root.init = (argv) ->
  logger argv
  factor = argv.factor

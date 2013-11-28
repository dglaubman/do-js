root = exports ? this

_ = require 'underscore'
{visit} = require '../visitor'
{trace} = require '../log'

root.run = (payloads) ->
  flat =_.flatten payloads, true  # Shallow (1 level)
  groups = _.groupBy flat, (d) -> d.event
  _.map groups, (v,k) -> {
    event: +k
    loss: _.reduce v, ((acc, elem) -> acc + elem.loss), 0
  }

root.init = ->

root = exports ? this

_ = require 'underscore'

root.run = (losses) ->
  _.reduce losses, (acc, bucket) ->
    acc.loss += bucket.loss
    acc

root.init = ->

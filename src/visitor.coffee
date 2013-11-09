root = exports ? this

_ = require 'underscore'
{construct} = require('./util')

root.visit = visitor = (f) ->
  (loss) ->
     _.map( loss, (v,k) ->
      if k.toUpperCase() is "LOSS"
        construct k, [f v]
      else
        construct k, [v] )

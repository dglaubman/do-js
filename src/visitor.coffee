root = exports ? this

_ = require 'underscore'
{construct} = require './util'
{trace, error} = require './log'
root.visit = visitor = (f) ->
  (loss) ->
     _.map( loss, (v,k) ->
      if typeof k isnt "string"
        error "Expected string key, got (k,v): "
        trace k
        trace v
      if k.toUpperCase() is "LOSS"
       construct k, [+((f v).toFixed 3)]
      else
        construct k, [v] )

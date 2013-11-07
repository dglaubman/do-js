root = exports ? this

_ = require 'underscore'
logger = require('./log')
{construct} = require('./util')

root.visitor = visitor = (f) ->
  (loss) ->
     _.map( loss, (v,k) ->
      if k.toUpperCase() is "LOSS"
        logger.log "(k,v): #{k}, #{f v}"
        construct k, [f v]
      else
        logger.log "(k,v): #{k}, #{v}"
        construct k, [v] )

root = exports ? this

_ = require 'underscore'
fs = require 'fs'
{visit} = require '../visitor'
{trace, error} = require '../log'

compile = (text) ->
  pattern = ///
    ^\s*
    (\d*\.?\d*)%                      # match share amount
    \s+SHARE\s+OF\s+
    (\d*\.?\d*|UNLIMITED)             # match limit amount
    \s+XS\s+
    (\d*\.?\d*)                       # match attachment amount
    \s*$
  ///i
  [share, limit, attach] = text.match(pattern)[1..3]
  share /= 100
  if (_.isString limit) and (_.isEqual 'UNLIMITED', limit.toUpperCase())
     limit = Infinity
  (loss) ->
    share * ( Math.min limit, Math.max( 0, loss - attach ) )

pay = ->

root.init = (argv) ->
  cdl = argv.cdl
  path = argv.path || '../contracts/'
  text = fs.readFileSync( path + cdl + ".cdl" ).toString()
  payout = compile text
  pay = visit payout


root.run = (losses) ->
  try
    _.map losses, (loss) ->
      _.object pay loss
  catch e
    error e

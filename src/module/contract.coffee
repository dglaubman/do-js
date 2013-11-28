root = exports ? this

_ = require 'underscore'
fs = require 'fs'
{visit} = require '../visitor'
{trace, error} = require '../log'

MAXLINELEN = 80

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
  try
    attach = 0
    [share, limit, attach] = text.match(pattern)[1..3]
    share /= 100
    if (_.isString limit) and (_.isEqual 'UNLIMITED', limit.toUpperCase())
      limit = Infinity
    (loss) ->
      share * ( Math.min limit, Math.max( 0, loss - attach ) )
  catch e
    error "#{e}: " + text[..80]

pay = ->

root.init = (argv) ->
  cdl = argv.cdl
  path = argv.path || '../contracts/'
  text = fs.readFileSync( path + cdl + ".cdl" ).toString()
  payout = compile text
  pay = visit payout


root.run = (payloads) ->
  throw "contract must have a single payload" unless payloads.length is 1
  losses = payloads[0]
  _.map losses, (loss) ->
    _.object pay loss

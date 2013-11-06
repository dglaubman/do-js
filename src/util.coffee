root = exports ? this
_ = require( 'underscore' )

root.fail = fail = (x) -> throw x

root.existy = existy = (x) -> x?

root.truthy = truthy = (x) -> x? and x

root.doWhen = doWhen = (cond, action) ->
  action() if truthy cond


root.cat = cat = () ->
  head = _.first(arguments)
  if (existy head)
    head.concat.apply head, _.rest( arguments )
  else
    []

root.construct = construct = (h, t) ->
  cat [h], _.toArray t

root.mapcat = mapcat = (f, coll) ->
  cat.apply null, _.map(coll, f)

butlast = (coll) -> _.toArray(coll).slice(0,-1)

root.interpose = interpose = (inter, coll) ->
  butlast  (mapcat ((e) -> construct e, [inter] ),    coll)

root.project = project = (table, keys) ->
  _.map( table, (o) ->
    _.pick.apply( null, construct( o, keys ) )
  )

root.rename = rename = (obj, names) ->
  _.reduce( names, (acc, nu, old) ->
      acc[nu] = obj[old] if _.has( obj, old )
      acc
  , _.omit.apply( null, construct( obj, _.keys names )))

root.as = as = (table, names) ->
  _.map table, (row) ->
    rename row, names

root.restrict = restrict = (table, pred) ->
  _.reduce( table, (t, row) ->
      if pred row
        t
      else
        _.without t, row
    , table )

root.average = average = (array) ->
  sum = _.reduce array, (a,b) -> a + b
  sum / _.size array

root.complement = complement =
  (pred) -> () -> not pred.apply null, _.toArray arguments

root.showObject = showObject = (o) -> o

root.plucker = plucker = (field) -> (obj) ->
  return false unless obj
  obj[field]


root.invoker = invoker = (name, method) ->
  (target) ->
    if not target then fail( "must provide a target" )
    targetMethod = target[name]
    args = _.rest arguments
    doWhen (targetMethod and (method is targetMethod)), ->
      targetMethod.apply target, args


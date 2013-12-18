root = exports ? this

root.RouteReady = (route, track) ->
  "ready|route|#{route}|track|#{track}"

root.Stopped = (type, name) ->
  "stopped|type|#{type}|name|#{name}"

root.Stat = (track, position, loss) ->
 "stat|track|#{track}|position|#{position}|loss|#{loss}"
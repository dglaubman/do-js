root = exports ? this

i = 0
GROUP = { id: i++, name: "group" }
CONTRACT = { id: i++, name: "contract" }
SCALE = { id: i++, name: "scale" }
INVERT = { id: i++, name: "invert" }
FILTER = { id: i++, name: "filter" }
CHOOSE = { id: i++, name: "choose" }

_ops = {
  GROUP
  CONTRACT
  SCALE
  INVERT
  FILTER
  CHOOSE
}
Ops = (name) ->
    op = _ops[name.toUpperCase()]
    op?.name or "unknown"

root.Ops = Ops
root = exports ? this

i = 10
OK = { id: i++, name: "ok" }
ERROR = { id: i++, name: "error" }

Status = {
  OK
  ERROR
}

root.Status = Status
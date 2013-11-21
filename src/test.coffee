# test:

root = exports ? this
{ log, trace } = require './log'

root.init = (argv) ->
  testdir = argv.path or "./test/"
  file = argv.test
  {payloads} = require "#{testdir}#{file}"
  log "Start test: #{file}"
  payloads

root.run = (transform, input) ->
  start = new Date()
  trace (transform input)
  stop = new Date()
  log "  done: #{stop - start}ms"


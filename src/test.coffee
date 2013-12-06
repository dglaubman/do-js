# test:

root = exports ? this
{ log, trace } = require './log'

root.init = (argv) ->
  testdir = argv.path or "./test/"
  iterations = argv.iter or 1
  file = argv.test
  {payloads} = require "#{testdir}#{file}"
  payloads

root.run = (transform, input) ->
  log "Start test: #{file}"
  log = new Date()
  trace (transform input)
  stop = new Date()
  log "  done: #{stop - start}ms"


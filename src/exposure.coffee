# Exposure async get
http = require 'http'
amqp = require ('amqp')
utils = require ('util')
logger = require ('./log')
url = require ('url')

error = (err) ->console.log err
fatal = (err) ->
   error err
   process.exit 0

host = 'ec2-50-16-67-125.compute-1.amazonaws.com'
vhost = 'v0.1.1'
xchange = 'exposureX'
replyxchange = 'exposureX'
completedQ = 'RiskItemsGetCompletedEvent'
edsX = ''
replyX = ''
edsGetQueue = 'RiskItemsGetEvent'
replyQName = ''
logger.verbose = true

trigger = (data) ->
   # send a reply via replyQueue
   replyX.publish(replyQName, data)
   console.log "published message queue=#{replyQName} data=#{data}"
  
connection = amqp.createConnection({host: host, vhost: vhost})
connection.on 'ready', ->
   edsX = connection.exchange xchange, {type: 'direct'}, -> # logger.log "exchange"
   replyX = connection.exchange replyxchange, {type: 'direct'}, -> # logger.log "exchange"

   connection.queue '', {exclusive: true}, (responseQ) ->
     responseQ.on 'error', error
     responseQ.on 'queueBindOk', ->
       responseQ.subscribe (message,headers, deliveryInfo) ->
         trigger message.data
      responseQ.bind(edsX, completedQ)
      console.log "listening on #{completedQ}"

sendToEDS = (data) ->
   headers = {
       MessageId: '1',
       UserId: '1',
       TenantId: '1',
       AuthenticationToken: 'none',
       ContextId: '333333',
       ApplicationId: '1',
       CorrelationId: 'none',
       EventType: 'RiskItemsGetEvent',
       ContentType: 'json',
       SubmitTime: '3:25:28 PM',
       key1: 'value1'}
   edsX.publish(edsGetQueue, data, {headers:headers})
   console.log "published message queue=#{edsGetQueue} data=#{data}"

server = http.createServer (req, res) -> 
   uri = url.parse(req.url);
   query = uri.query.split "&"
   params = {}
   query.forEach (nv) ->
     nvp = nv.split "="
     params[nvp[0]] = nvp[1]
   replyQName = params["reply"]
   console.log req.method,req.url, uri.pathname, replyQName
   switch req.method
     when 'POST'
        value = ''
        req.on 'data', (chunk) -> value +=chunk
        req.on 'end', () ->
           sendToEDS(value)
   res.end 'DID it\n'

server.listen 8000


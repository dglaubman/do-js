root = exports ? this

semver = "0.1.1"

root.config =
  serverX: 'serverX'
  workX:   'workX'
  signalX: 'signalX'
  execQ:   'execQ'
  url:     'ws://ca1-ng-ds-22.rms.com:8001/amqp'
  virtualhost:  "v#{semver}"
  credentials: { username: 'guest', password: 'guest' }


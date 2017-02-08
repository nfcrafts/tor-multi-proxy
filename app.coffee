express = require 'express'
EventEmitter = require 'events'

emitter = new EventEmitter

Tor = require './Tor.coffee'

tors = Tor.generateTors 100

for tor in tors
  do ->
    _tor = tor
    _tor.saveConfig()

    _tor.run()
    .then ->
      emitter.emit "tor#{_tor.id}.ready"
      console.log _tor.ip
    , (err) ->
      console.log "tor#{_tor.id}.error"
      console.log err

app = express()

app.get '/', (req, res) ->
  Tor.makeRequest tors,
    url: req.query.url,
  .then (data) ->
    res.send data
  , (err) ->
    res.status 500
    res.send err.toString()

app.listen 8877, ->
  console.log 'listening on *:8877'
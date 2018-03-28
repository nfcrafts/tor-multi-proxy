spawn = require('child_process').spawn
Agent = require 'socks5-https-client/lib/Agent'
request = require 'request'
EventEmitter = require 'events'
fs = require 'fs'
fx = require 'mkdir-recursive'

class TorEventEmitter extends EventEmitter

class Tor
  constructor: (@id = 1, @configFile = "", @config) ->
    @emitter = new TorEventEmitter
    @active = false

    unless @config
      @config =
        SocksPort: 9050 + @id
        DataDirectory: "tor_configs/tor#{@id}/data"

    @lastUse = new Date

    do @createDirectory
    do @parseConfigFile
    do @saveConfig

Tor::run = ->
  new Promise (resolve, reject) =>
    @process = spawn('tor', ['-f', @configFile]);

    @pid = @process.pid

    @process.stdout.on 'data', (data) =>
      if data.toString().indexOf('Bootstrapped 100%: Done') > 0
        
        resolve "ready"

    @process.on 'exit', (code, signal) =>
      @active = false
      unless code == 0
        reject code
  .then =>
    @getIp()
  .then (ip) =>
    @active = true 
    Promise.resolve ip

Tor::stop = ->
  @process.kill()
  @active = false
  Promise.resolve()

Tor::restart = ->
  @stop()
  @run()
  .catch (err) =>
    console.log err

Tor::parseConfigFile = ->
  
  if fs.existsSync(@configFile)
    _configFile = fs.readFileSync(@configFile).toString()

    for line in _configFile.split("\n")
      words = line.split(" ")

      if words.length > 1
        @config[words[0]] = words[1]

Tor::saveConfig = ->
  _configFile = ""

  for key of @config
    _configFile += "#{key} #{@config[key]}\n"

  fs.writeFileSync(@configFile, _configFile)

Tor::createDirectory = ->
  unless fs.existsSync(@config.DataDirectory)
    fx.mkdirSync @config.DataDirectory

Tor::touchLastUse = ->
  @lastUse = new Date

Tor::getIp = ->
  @makeRequest
    url: 'https://api.ipify.org/'
  .then (data) =>
    @ip = data
    console.log @ip
    Promise.resolve data

Tor::makeRequest = (options) ->
  do @touchLastUse
  new Promise (resolve, reject) =>
    options.strictSSL = true
    agentOptions = {}
    agentOptions.socksPort = @config.SocksPort
    options.agent = new Agent agentOptions
    request options, (err, res) =>
      if err
        return reject err
      resolve res.body

Tor.generateTors = (count, startId = 1) ->
  ret = []
  for i in [startId..count+startId-1]
    id = i
    ret.push new Tor id, "tor_configs/tor#{id}/torrc"
  ret

Tor.getActiveTors = (tors) ->
  ret = []
  for tor in tors
    if tor.active
      ret.push tor
  ret

lastIp = null
Tor.getDifferentIpTors = (tors) ->
  unless tors[0] then return []
  unless lastIp then return tors

  ret = []
  for tor in tors
    if tor.ip != lastIp
      ret.push tor
  ret

Tor.getMaxLastUse = (tors) ->
  unless tors[0] then return null
  ret = tors[0]
  _date = new Date
  for tor in tors
    if _date - tor.lastUse  > _date - ret.lastUse
      ret = tor
  ret

Tor.makeRequest = (tors, options) ->
  tors = Tor.getActiveTors tors
  tors = Tor.getDifferentIpTors tors
  tor = Tor.getMaxLastUse tors
  console.log "Making request through tor##{tor.id} with ip #{tor.ip}"
  lastIp = tor.ip
  tor.makeRequest options
  .then (res) ->
    Promise.resolve res
  , (err) ->
    Promise.reject err

module.exports = Tor
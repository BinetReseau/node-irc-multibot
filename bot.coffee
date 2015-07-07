_ = require "lodash"
irc = require "irc"
express = require "express"
fs = require "fs"
yaml = require "js-yaml"
Q = require "q"
bodyParser = require "body-parser"

unless String::trim then String::trim = -> @replace(/^\s+/, '').replace(/\s+$/, '')

chanserv_invite = (client, nick, chan) ->
  Q.Promise (resolve, reject) =>
    client.addListener "raw", (message) =>
      if message.command == '341' or \
          (message.command == "INVITE" and message.nick == 'ChanServ' \
          and message.args[0] == client.nick and message.args[1] == chan)
        resolve()
      else if message.command == '473'
        reject(message)
    client.say "chanserv", "invite #{chan} #{nick}"

nickserv_identify = (client, nick, password) ->
  Q.Promise (resolve, reject) =>
    client.addListener "raw", (message) =>
      if message.command == '900'
        resolve()
    client.say "nickserv", "identify #{password}"



class IRCBot
  constructor: (@conf) ->
    @clients = {}
    @keys_map = {}
    for user, key of conf["authorized-keys"]
      @keys_map[key.toString()] = user


  create_client: (nick) ->
    console.log "Connecting using nick '#{nick}'"
    client = new irc.Client @conf.server, nick, @conf.serverconfig

    @init_client client, nick

    Q.Promise (resolve, reject) =>
      client.addListener "registered", () =>
        @clients[nick] = client

        if nick of conf.nickserv
          password = conf.nickserv[nick]
          console.log "Identifying with nick '#{nick}'"
          nickserv_identify(client, nick, password).then () =>
            resolve(client)
        else
          resolve(client)

  init_client: (client, nick) ->
    client.addListener "error", (message) =>
      console.error "IRC error @#{nick}:", message

    # client.addListener "raw", (message) =>
    #   console.log "IRC message @#{nick}:", message


  get_client: (nick) ->
    if nick of @clients
      Q(@clients[nick])
    else
      Q(@create_client nick)
      .timeout 60000, "Could not connect to server"


  join_chan: (nick, chan) ->
    @get_client(nick).then (client) =>
      if chan not of client.chans
        promise = if chan in @conf.chanserv
            console.log "Asking chanserv for an invite on #{chan}"
            Q(chanserv_invite client, nick, chan)
            .timeout 30000, "Chanserv probably refused"
          else
            Q()
        promise.then () =>
          console.log "Joining chan '#{chan}' using nick '#{nick}'"
          Q.Promise (resolve, reject) =>
            client.join chan, () =>
              resolve()
          .timeout 30000, "Could not join chan"
      else
        return


  say: (nick, chan, msg) ->
    if msg == ""
      Q.reject()
    @get_client(nick).then (client) =>
      @join_chan(nick, chan).then () =>
        console.log "-> #{nick}@#{chan}: #{msg}"
        client.say chan, msg


  authorize: (key) ->
    if key not of @keys_map
      false
    else
      @keys_map[key]


## Load conf
conf = yaml.safeLoad fs.readFileSync("bot.yml", "utf8")
conf.chanserv ?= []
conf.nickserv ?= {}

bot = new IRCBot(conf)

## Initialize app
app = express()
app.use bodyParser.json()
app.use bodyParser.urlencoded
  extended: true

## Initialize endpoints
_.forEach conf.entrypoints, (ep, url) ->
  app.get "/"+url, (req, res) ->
    html = '<form action="#" method="POST">'
    html += 'Key: <input type="text" name="key"><br>'
    html += 'Message: <input type="text" name="message"><br>'
    html += '<input type="submit" value="Ok">'
    res.send(html)


_.forEach conf.entrypoints, (ep, url) ->
  app.post "/"+url, (req, res) ->
    key = req.body.key.toString()
    user = bot.authorize(key)

    if not user
      console.error "Unknown key '#{key}'"
      res.status(401).send("Unknown key")
      return

    if not user in ep["authorized_users"]
      console.error "User '#{user}' cannot push to #{url}"
      res.status(403).send("You are not allowed to perform this action")
      return

    msg = req.body.message
    if not msg?
      console.error "#{user}:/#{url}: No message specified"
      res.status(400).send("No message specified")
      return

    msg = msg.trim()
    if msg == ""
      console.error "#{user}:/#{url}: Empty message, ignoring"
      return

    console.log "<- #{user}:/#{url}:", msg

    nick = ep.nick ? conf.default_nick
    prefix = ep.prefix ? ""
    bot.say nick, ep.chan, prefix + msg
    .then () ->
      res.status(200).send("Ok")
    .catch (err) ->
      console.error err
      res.status(500).send(err.toString())


app.listen conf.listen

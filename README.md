# node-irc-multibot

An IRC bot controlled via http(s) endpoints.

## Configuration

The bot reads its configuration from bot.yml, and starts up a webserver on port 3000 (see bot.yml.dist for an example).
It then waits for POST requests, and forwards the received messages to an IRC chan when applicable.

Available settings:

###### server, serverconfig

Configure the irc server and connection details

Example:

    server: irc.freenode.net
    serverconfig:
      userName: Node-bot
      # port: 6767
      # secure: true
      autoRejoin: true
      stripColors: true

###### authorized-keys

Set a mapping of users and keys that will be used to authorize access to the entrypoints.

Example:

    authorized-keys:
      user1: "secretk3y"

###### entrypoints

For each entry, the bot will react to a POST request to the given URL and forward the message to the chan specified.

Example:

    entrypoints:
      test:
        chan: "#test"
        authorized_users:
          - user1
        nick: node-multibot

`POST /test key=secretk3y&message=Hello` will then send the message "Hello" to chan #test with nick node-multibot if the key matches one of the authorized users for this entrypoint.

###### nickserv, chanserv

The bot can handle invite-only chans and registered nicks via the `chanserv` and `nickserv` settings.

Example:

    nickserv:
      node-multibot: "qwertyuiop"

Will identify to nickserv when using nick `node-multibot`

    chanserv:
      - "#test"

Will ask chanserv for an invite when posting to chan `#test`

## Usage

    npm install

    npm start

    echo "Hello, I'm a bot" | ./pipe.sh foobar42 localhost:3000/entrypoint

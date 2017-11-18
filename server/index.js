var express = require('express')
var app = express()
var http = require('http').Server(app)
var io = require('socket.io')(http)
const { Pool, Client } = require('pg')

const pool = new Pool({
  connectionString: 'postgres://hsunami10:ewoks4life@proxichat.csgmdrzqsp2i.us-east-2.rds.amazonaws.com:5432/proxichat'
})

pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err)
  process.exit(-1)
})

// ========================================================================== //
var port = 3000
http.listen(port, function() {
  console.log('Server listening on port ' + port)
})

// NOTE: ONLINE ONLY
var SOCKETID_TO_USERNAME = {} // Links actual socket.id to username
var GROUP_TO_USERNAMES = {} // Holds all the usernames that are in a group_id
var USERNAME_TO_GROUPS = {} // Holds all the group_ids the user is in
var USERNAME_TO_SOCKET = {} // Links username to corresponding socket

// NOTE: Declare namespaces
var proxichat_nsp = io.of('/proxichat_namespace')

// ========================================================================== //

// NOTE: ProxiChat app connection - "online"
proxichat_nsp.on('connection', socket => {
  console.log('connected to proxichat namespace - online: ' + socket.id);

  // This sets the sockets so users are able to send to these sockets
  socket.on('go_online', username => {
    SOCKETID_TO_USERNAME[socket.id] = username
    USERNAME_TO_SOCKET[username] = socket

    console.log(SOCKETID_TO_USERNAME);
  })

  socket.on('update_location_and_get_groups', data => {
    let username = data.username
    let coordinates = data.latitude + ' ' + data.longitude
    let radius = data.radius

    pool.query(`SELECT * FROM update_location_proxichat(
      '${username}',
      '${coordinates}',
      ${radius})`,
      (err, res) => {
        if (err) {
          // TODO: Handle so it doesn't crash
          socket.emit('update_location_and_get_groups_response', { success: false })
          console.log(err);
        } else {
          socket.emit('update_location_and_get_groups_response', { success: true, data: res.rows })
        }
      })
  })

  socket.on('disconnect', () => {
    // TODO: User USERNAME_TO_GROUPS to find all group_ids,
    // then delete that username from GROUP_TO_USERNAMES
    console.log('disconnected from proxichat_namespace: ' + socket.id);
    delete USERNAME_TO_SOCKET[SOCKETID_TO_USERNAME[socket.id]]
    delete SOCKETID_TO_USERNAME[socket.id]
  })
})

// NOTE: General Connection - Not "online" - welcome, log in, sign up
io.on('connection', socket => {

  // Sign up
  socket.on('sign_up', (username, password) => {
    // First connect to check whether the username exists
    pool.connect()
      .then(client => {
        return client.query(`SELECT * FROM users WHERE username = '${username}'`)
          .then(users => {
            if (users.rows.length == 0) {
              client.query(`INSERT INTO users (username, password) VALUES ('${username}', '${password}')`)
              socket.emit('sign_up_response', { success: true, error_msg: '' })
            } else {
              socket.emit('sign_up_response', { success: false, error_msg: 'Username already taken.' })
            }
            client.release()
          })
      })
      .catch(error => {
        client.release()
        console.log(error.stack);
      })
  })

  // Sign in
  socket.on('sign_in', (username, password) => {
    pool.query(`SELECT password FROM users WHERE username = '${username}'`)
      .then(user => {
        if(user.rows.length == 0) {
          socket.emit('sign_in_response', { success: false, error_msg: 'Username does not exist.' })
        } else {
          if(user.rows[0].password == password) {
            socket.emit('sign_in_response', { success: true, error_msg: '' })
          } else {
            socket.emit('sign_in_response', { success: false, error_msg: 'Incorrect password.' })
          }
        }
      })
      .catch(e => setImmediate(() => { throw e }))
  })

  socket.on('disconnect', () => {
    console.log('disconnected from main namespace /');
  })
})

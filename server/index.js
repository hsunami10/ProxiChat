var express = require('express')
var app = express()
var http = require('http').Server(app)
var io = require('socket.io')(http)
const { Pool } = require('pg')

const pool = new Pool({
  host: 'proxichat.csgmdrzqsp2i.us-east-2.rds.amazonaws.com',
  port: 5432,
  database: 'proxichat',
  user: 'hsunami10',
  password: 'ewoks4life'
})

pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err)
  process.exit(-1)
})

// ========================================================================== //

http.listen(3000, function() {
  console.log('Server listening on port 3000')
})

var SOCKETID_TO_USERNAME = {}
var USERNAME_TO_SOCKET = {}

// NOTE: Declare namespaces
var proxichat_nsp = io.of('/proxichat_namespace')

// ========================================================================== //

// NOTE: ProxiChat app connection - "online"
proxichat_nsp.on('connection', socket => {
  console.log('connected to proxichat namespace - online: ' + socket.id);

  socket.on('go_online', username => {
    SOCKETID_TO_USERNAME[socket.id] = username
    USERNAME_TO_SOCKET[username] = socket
  })

  socket.on('disconnect', () => {
    console.log('disconnected from proxichat_namespace: ' + socket.id);
    delete USERNAME_TO_SOCKET[SOCKETID_TO_USERNAME[socket.id]]
    delete SOCKETID_TO_USERNAME[socket.id]
  })
})

// NOTE: General Connection - Not "online" - welcome, log in, sign up
io.on('connection', socket => {
  console.log('user connected with socket id: ' + socket.id)

  // Sign up
  socket.on('sign_up', (username, password) => {
    pool.connect()
      .then(client => {
        return client.query(`SELECT * FROM users WHERE username = '${username}'`)
          .then(user => {
            if(user.rows.length == 0) {
              client.query(`INSERT INTO users (username, password) VALUES ('${username}', '${password}')`)
              client.release()
              socket.emit('sign_up_response', { success: true, error_msg: '' })
            } else {
              client.release()
              socket.emit('sign_up_response', { success: false, error_msg: 'Username has been taken.' })
            }
          })
      })
      .catch(error => {
        client.release()
        console.log(error.stack);
      })
  })

  // Sign in
  socket.on('sign_in', (username, password) => {
    pool.connect()
    .then(client => {
      return client.query(`SELECT * FROM users WHERE username = '${username}'`)
        .then(user => {
          if(user.rows.length == 0) {
            client.release()
            socket.emit('sign_in_response', { success: false, error_msg: 'Username does not exist.' })
          } else {
            if(user.rows[0].password == password) {
              socket.emit('sign_in_response', { success: true, error_msg: '' })
            } else {
              socket.emit('sign_in_response', { success: false, error_msg: 'Incorrect password.' })
            }
          }
        })
    })
    .catch(error => {
      client.release()
      console.log(error.stack);
    })
  })

  socket.on('disconnect', () => {
    console.log('user disconnected with socket id: ' + socket.id)
    delete SOCKETID_TO_USERNAME[socket.id]
  })
})

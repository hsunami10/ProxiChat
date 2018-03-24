var express = require('express')
var app = express()
var http = require('http').Server(app)
var io = require('socket.io')(http)
var shortid = require('shortid')
const { Pool, Client } = require('pg')

const pool = new Pool({
  // connectionString: 'postgres://hsunami10:ewoks4life@proxichat.csgmdrzqsp2i.us-east-2.rds.amazonaws.com:5432/proxichat'
  connectionString: 'postgres://michaelhsu:ewoks4life@localhost:5432/proxichat'
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
var GROUP_TO_USERNAMES = {} // Holds all online members in group
var USERNAME_TO_GROUPS = {} // NOTE: handle "user has left the group" message - one group ID per username
var USERNAME_TO_SOCKET = {} // Links username to corresponding socket

// // NOTE: Declare namespaces
var proxichat_nsp = io.of('/proxichat_namespace')

// ========================================================================== //

// NOTE: ProxiChat app connection - "online"
proxichat_nsp.on('connection', socket => {
  console.log('connected to proxichat namespace - online: ' + socket.id);

  socket.emit('join_success')

  // NOTE: Delete account
  socket.on('delete_account', username => {
    pool.query(`DELETE FROM users WHERE username = '${username}'`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('delete_account_response', { success: false })
        console.log(err);
      } else {
        socket.emit('delete_account_response', { success: true })
      }
    })
  })

  // NOTE: Get starred groups
  socket.on('get_starred_groups', username => {
    pool.query(`SELECT groups.id, groups.title, groups.password, groups.created_by, groups.is_public, groups.coordinates, groups.number_members, groups.date_created FROM groups INNER JOIN users_groups ON users_groups.group_id = groups.id WHERE users_groups.username = '${username}'`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('get_starred_groups_response', { success: false, error_msg: 'There was a problem getting your groups. Please try again.' })
        console.log(err);
      } else {
        socket.emit('get_starred_groups_response', { success: true, groups: res.rows })
      }
    })
  })

  // =================== EDIT PROFILE EVENTS START ===================
  socket.on('update_radius', (username, radius) => {
    pool.query(`UPDATE users SET radius = ${radius} WHERE username = '${username}'`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('update_radius_response', { error_msg: 'There was a problem updating your radius. Please try again.' })
        console.log(err);
      }
    })
  })
  socket.on('update_profile', (username, type, content) => {
    // NOTE: 1 - password, 2 - bio, 3 - email
    switch (type) {
      case 1:
        pool.query(`UPDATE users SET password = '${content}' WHERE username = '${username}'`, (err, res) => {
          if (err) {
            // TODO: Handle so it doesn't crash
            socket.emit('update_profile_response', { error_msg: 'There was a problem updating your password. Please try again.' })
            console.log(err);
          } else {
            console.log('update password success');
          }
        })
        break
      case 2:
        pool.query(`UPDATE users SET bio = '${content}' WHERE username = '${username}'`, (err, res) => {
          if (err) {
            // TODO: Handle so it doesn't crash
            socket.emit('update_profile_response', { error_msg: 'There was a problem updating your bio. Please try again.' })
            console.log(err);
          } else {
            console.log('update bio success');
          }
        })
        break
      case 3:
        pool.query(`UPDATE users SET email = '${content}' WHERE username = '${username}'`, (err, res) => {
          if (err) {
            // TODO: Handle so it doesn't crash
            socket.emit('update_profile_response', { error_msg: 'There was a problem updating your email. Please try again.' })
            console.log(err);
          } else {
            console.log('update email success');
          }
        })
        break
      default:

    }
  })
  // =================== EDIT PROFILE EVENTS END ===================

  // NOTE: Update location and groups
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
          socket.emit('update_location_and_get_groups_response', { success: false, data: [], error_msg: 'There was a problem getting your location. Please try again.' })
          console.log(err);
        } else {
          socket.emit('update_location_and_get_groups_response',  { success: true, groups: res.rows, error_msg: '' })
        }
      })
  })

  // NOTE: Update location and get groups after creating group
  socket.on('update_location_and_get_groups_create', data => {
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
          socket.emit('update_location_and_get_groups_create_response', { success: false, groups: [], error_msg: 'There was a problem getting groups. Please try again.' })
          console.log(err);
        } else {
          // BUG: This gets ALL groups when going to profile/settings and back, then reloading
          socket.emit('update_location_and_get_groups_create_response',  { success: true, groups: res.rows, error_msg: '' })
        }
      })
  })

  // NOTE: Request to join a private group
  socket.on('join_private_group', data => {
    let group_id = data.id
    let enteredPassword = data.passwordEntered
    let rowIndex = data.rowIndex

    pool.query(`SELECT title FROM groups WHERE id = '${group_id}' AND password = '${enteredPassword}'`,
      (err, res) => {
        if (err) {
          // TODO: Handle so it doesn't crash
          socket.emit('join_private_group_response', { success: false, error_msg: 'There was a problem joining. Please try again.' })
          console.log(err);
        } else {
          // If there is no group with that password, then entered password is incorrect
          if (res.rows.length === 0) {
            socket.emit('join_private_group_response', { success: false, error_msg: 'The password you entered was incorrect.' })
          } else {
            socket.emit('join_private_group_response', { success: true, error_msg: '', row_index: rowIndex })
          }
        }
    })
  })

  // NOTE: Joining and leaving a room (group chat) (ONLINE ONLY)
  socket.on('join_room', data => {
    var group_id = data.group_id
    var username = data.username

    socket.join('room-' + group_id)

    // Add to object to handle leaving the room while terminating app or logging out
    // TODO: Finish later
    // if (USERNAME_TO_GROUPS[username]) {
    //   USERNAME_TO_GROUPS[username][group_id] = group_id
    // } else {
    //   USERNAME_TO_GROUPS[username] = {}
    //   USERNAME_TO_GROUPS[username][group_id] = group_id
    // }

    proxichat_nsp.in('room-' + group_id).emit('group_stats', { number_online: proxichat_nsp.adapter.rooms['room-' + group_id].length })
  })

  // NOTE: Only triggered when going back to groups page and not starred (ONLINE ONLY)
  socket.on('leave_room', data => {
    var group_id = data.group_id
    var username = data.username

    socket.leave('room-' + group_id)
    // TODO: Finish later
    // delete USERNAME_TO_GROUPS[username][group_id]

    // Check if the last person has left the room (no one online) - so won't throw error
    if (proxichat_nsp.adapter.rooms['room-' + group_id]) {
      proxichat_nsp.in('room-' + group_id).emit('group_stats', { number_online: proxichat_nsp.adapter.rooms['room-' + group_id].length })
    }
  })

  // NOTE: Getting messages
  // TODO: Paginate
  socket.on('get_messages_on_start', group_id => {
    pool.query(`SELECT messages.id, messages.author, messages.group_id, messages.content, messages.date_sent, users.picture FROM messages INNER JOIN users ON messages.author = users.username WHERE group_id = '${group_id}' ORDER BY messages.date_sent ASC`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('get_messages_on_start_response', { success: false, error_msg: 'There was a problem getting messages. Please try again.' })
        console.log(err);
      } else {
        // BUG: get_messages_on_start_response here is triggered multiple times???
        socket.emit('get_messages_on_start_response', { success: true, error_msg: '', messages: res.rows })
      }
    })
  })

  // NOTE: Sending messages
  socket.on('send_message', data => {
    socket.to('room-' + data.group_id).emit('receive_message', {
      author: data.username,
      content: data.content,
      date_sent: data.date_sent,
      id: data.id,
      picture: data.picture,
      group_id: data.group_id
    })
    pool.query(`INSERT INTO messages (id, author, group_id, content) VALUES ('${data.id}', '${data.username}', '${data.group_id}', '${data.content}')`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        console.log(err);
      } else {
        // TODO: Send confirmation that it has been successfully sent
      }
    })
  })

  // NOTE: Create a new private/public group
  socket.on('create_group', data => {
    var g_id = shortid.generate()

    // TODO: Add group to database - use create_group_proxichat
    pool.query(`SELECT create_group_proxichat('${g_id}', '${data.group_name}', '${data.group_password}', '${data.created_by}', '${data.group_date}', ${data.is_public}, '${data.group_coordinates}', '${shortid.generate()}')`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('create_group_response', { success: false, error_msg: 'There was a problem creating a group. Please try again.' })
        console.log(err);
      } else {
        socket.emit('create_group_response', { success: true, error_msg: '', group_id: g_id })
      }
    })
  })

  // NOTE: Get the user's info on startup
  socket.on('get_user_info', username => {
    pool.query(`SELECT picture, password, radius, is_online, coordinates, bio, username, email FROM users WHERE username = '${username}'`, (err, res) => {
      if (err) {
        // TODO: Handle so it doesn't crash
        socket.emit('get_user_info_response', { success: false, error_msg: 'There was a problem getting your account information. Please try again.' })
        console.log(err);
      } else {
        socket.emit('get_user_info_response', { success: true, error_msg: '', data: res.rows[0] })
      }
    })
  })

  socket.on('disconnect', () => {
    // TODO: user USERNAME_TO_GROUPS to send "user has left the group" to room if not starred
    // NOTE: Check if is starred in database, if not, then use socketID to get username to get group_id (if exists) to get room
    // NOTE: If "starred", then in database
    console.log('disconnected from proxichat_namespace: ' + socket.id);
    delete USERNAME_TO_SOCKET[SOCKETID_TO_USERNAME[socket.id]]
    delete SOCKETID_TO_USERNAME[socket.id]
  })
})

// NOTE: General Connection - Not "online" - welcome, log in, sign up
io.on('connection', socket => {

  // NOTE: Sign up
  socket.on('sign_up', (username, password, email) => {
    // First connect to check whether the username exists
    pool.connect()
      .then(client => {
        return client.query(`SELECT * FROM users WHERE username = '${username}' OR email = '${email}'`)
          .then(users => {
            if (users.rows.length === 0) {
              client.query(`INSERT INTO users (username, password, email) VALUES ('${username}', '${password}', '${email}')`)
              socket.emit('sign_up_response', { success: true, error_msg: '' })
            } else {
              socket.emit('sign_up_response', { success: false, error_msg: 'Username/email already taken.' })
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
        if(user.rows.length === 0) {
          socket.emit('sign_in_response', { success: false, error_msg: 'Username does not exist.' })
        } else {
          if(user.rows[0].password === password) {
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

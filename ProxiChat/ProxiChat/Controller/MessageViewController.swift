//
//  MessageViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/18/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD
import SwiftDate
import ChameleonFramework

/*
 TODO / BUGS
 - REMEMBER TO HAVE ISALERT IN A MESSAGE OBJECT ALWAYS
 - find a way to display dates on messages
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
    - only send "user has left" message when NOT STARRED
 */

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    var groupInformation: Group!
    var socket: SocketIOClient!
    var messageArray: [Message] = [Message]()
    var username: String!
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    @IBOutlet var messageTextField: UITextField!
    @IBOutlet var sendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextField.delegate = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Trigger an action whenever the table view is tapped
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        
        messageTextField.keyboardType = .alphabet
        messageTableView.separatorStyle = .none
        
        // Join room and get messages
        // TODO: Paginate messages
        socket.emit("join_room", [
            "group_id": groupInformation.id,
            "username": username
            ])
        
        configureTableView()
        self.view.layoutIfNeeded()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Realtime receiving messages
        socket.on("receive_message") { (data, ack) in
            print("received alert message")
            let isAlert = JSON(data[0])["is_alert"].boolValue
            if isAlert {
                let messageObj = Message()
                let username = JSON(data[0])["username"].stringValue
                messageObj.isAlert = true
                messageObj.author = username
                
                // If it's an alert of the user joining
                if JSON(data[0])["joined"].boolValue {
                    messageObj.joined = true
                } else { // If it's an alert of the user leaving
                    messageObj.joined = false
                }
                
                self.messageArray.append(messageObj)
            } else {
                let messageObj = Message()
                
                messageObj.author = JSON(data[0])["author"].stringValue
                messageObj.content = JSON(data[0])["content"].stringValue
                messageObj.dateSent = JSON(data[0])["date_sent"].stringValue
                messageObj.id = JSON(data[0])["id"].stringValue
                messageObj.isAlert = false
                messageObj.picture = JSON(data[0])["picture"].stringValue
                
                self.messageArray.append(messageObj)
            }
            self.configureTableView()
            self.messageTableView.reloadData()
        }
        // Get messages on join room
        socket.on("get_messages_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            let messages = JSON(data[0])["messages"].arrayValue
            
            if success {
                for message in messages {
                    let messageObj = Message()
                    
                    messageObj.author = message["author"].stringValue
                    messageObj.content = message["content"].stringValue
                    messageObj.dateSent = message["date_sent"].stringValue
                    messageObj.groupID = message["group_id"].stringValue
                    messageObj.id = message["id"].stringValue
                    messageObj.isAlert = message["is_alert"].boolValue
                    messageObj.picture = message["picture"].stringValue
                    
                    self.messageArray.append(messageObj)
                }
                self.configureTableView()
                self.messageTableView.reloadData()
            } else {
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: IBOutlet Actions
    @IBAction func goBackToGroups(_ sender: Any) {
        self.dismiss(animated: true) {
            self.socket.emit("leave_room", [
                "group_id": self.groupInformation.id,
                "username": self.username
                ])
        }
    }
    @IBAction func showGroupInfo(_ sender: Any) {
        print("show group info")
    }
    @IBAction func sendPressed(_ sender: Any) {
        // TODO: socket emit send_message event
        if messageTextField.text?.split(separator: " ").count != 0 {
            // TODO: Set enabled to false when sending so won't be spammy
            print(messageTextField.text)
            messageTextField.endEditing(true)
        }
    }
    
    // MARK: UITableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if messageArray[indexPath.row].isAlert {
            let alertCell = messageTableView.dequeueReusableCell(withIdentifier: "alertMessageCell", for: indexPath) as! AlertMessageCell
            
            // Check for join or leave alert
            if messageArray[indexPath.row].joined == true {
                alertCell.content.text = messageArray[indexPath.row].author + " has joined the group."
            } else {
                alertCell.content.text = messageArray[indexPath.row].author + " has left the group."
            }
            return alertCell
        } else {
            // TODO: Add date later
            let cell = messageTableView.dequeueReusableCell(withIdentifier: "messageCell", for: indexPath) as! MessageCell
            cell.content.text = messageArray[indexPath.row].content
            cell.username.text = messageArray[indexPath.row].author
            
            if messageArray[indexPath.row].picture == "" {
                cell.userPicture.image = UIImage(named: "noPicture")
            } else {
                cell.userPicture.image = UIImage(named: messageArray[indexPath.row].picture)
            }
            return cell
        }
    }
    
    /// Change the height based on content. If estimated height is wrong, then change height based on constraints
    func configureTableView() {
        messageTableView.rowHeight = UITableViewAutomaticDimension
        messageTableView.estimatedRowHeight = 120.0
    }
    
    @objc func tableViewTapped() {
        messageTableView.endEditing(true)
    }
    
    // MARK: NotificationCenter Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            // Get keyboard animation duration
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            // Get keyboard height
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            
            // Animate
            UIView.animate(withDuration: duration) {
                self.typingViewHeight.constant = 50 + keyboardHeight // Change typing view height
                self.messageTableView.frame = self.messageTableView.frame.offsetBy(dx: CGFloat(0), dy: keyboardHeight) // Shift table view up
                self.view.layoutIfNeeded() // If something in the view changed, then redraw/rerender
            }
        }
    }
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            
            UIView.animate(withDuration: duration) {
                self.typingViewHeight.constant = 50
                self.messageTableView.frame = self.messageTableView.frame.offsetBy(dx: CGFloat(0), dy: -keyboardHeight)
                self.view.layoutIfNeeded()
            }
        }
    }
}

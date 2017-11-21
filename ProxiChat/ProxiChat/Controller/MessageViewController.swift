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
 - BUG: Alert message won't center??? - should I show to current user or no?
 - find a way to display dates on messages
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
    - when terminating app, request from database, if no results, then send - user has left the group
    - only send "user has left" message when NOT STARRED
 */

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, JoinGroupDelegate {

    var groupInformation: Group!
    var socket: SocketIOClient!
    var messageArray: [Message] = [Message]()
    var username: String!
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    @IBOutlet var messageTextField: UITextField!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var messageTableViewHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        
        eventHandlers()
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextField.delegate = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Trigger an action whenever the table view is tapped
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        
        // Register nibs
        messageTableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "messageCell")
        messageTableView.register(UINib(nibName: "AlertMessageCell", bundle: nil), forCellReuseIdentifier: "alertMessageCell")
        
        messageTextField.keyboardType = .alphabet
        messageTableView.separatorStyle = .none
        messageTableViewHeightConstraint.constant = self.view.frame.height - (75 + 50) // TODO: Change later to make it more responsive
        
        // Get messages - on response, join room
        // TODO: Paginate messages
        socket.emit("get_messages_on_start", groupInformation.id)
        
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
    
    // MARK: IBOutlet Actions
    @IBAction func goBack(_ sender: Any) {
        // TODO: Check whether it's starred or not
        slideRightTransition()
        UIView.setAnimationsEnabled(false)
        performSegue(withIdentifier: "goBackToGroups", sender: self)
        socket.emit("leave_room", [
            "group_id": groupInformation.id,
            "username": username
            ])
    }
    @IBAction func showGroupInfo(_ sender: Any) {
        print("show group info")
    }
    @IBAction func sendPressed(_ sender: Any) {
        if messageTextField.text?.split(separator: " ").count != 0 {
            messageTextField.endEditing(true)
            messageTextField.isEnabled = false
            sendButton.isEnabled = false
            
            // TODO: ***Change Date***
            // TODO: ***Get picture***
            socket.emit("send_message", [
                "username": username,
                "content": messageTextField.text!,
                "date_sent": String(describing: Date()),
                "group_id": groupInformation.id,
                "id": String(describing: UUID()),
                "picture": ""
                ])
            
            messageTextField.isEnabled = true
            sendButton.isEnabled = true
            messageTextField.text = ""
            scrollToBottom()
        }
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Realtime receiving messages
        socket.on("receive_message") { (data, ack) in
            let isAlert = JSON(data[0])["is_alert"].boolValue
            if isAlert {
                let messageObj = Message()
                messageObj.isAlert = true
                messageObj.content = JSON(data[0])["content"].stringValue

                self.messageArray.append(messageObj)
            } else {
                let messageObj = Message()
                
                messageObj.author = JSON(data[0])["author"].stringValue
                messageObj.content = JSON(data[0])["content"].stringValue
                messageObj.dateSent = JSON(data[0])["date_sent"].stringValue
                messageObj.id = JSON(data[0])["id"].stringValue
                messageObj.groupID = JSON(data[0])["group_id"].stringValue
                messageObj.isAlert = false
                messageObj.picture = JSON(data[0])["picture"].stringValue
                
                self.messageArray.append(messageObj)
            }
            self.configureTableView()
            self.messageTableView.reloadData()
        }
        
        // Get messages on join room
        socket.on("get_messages_on_start_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            let messages = JSON(data[0])["messages"].arrayValue
            UIView.setAnimationsEnabled(true)
            
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
                
                // Join room after you get messages
                self.socket.emit("join_room", [
                    "group_id": self.groupInformation.id,
                    "username": self.username
                    ])
                self.scrollToBottom()
            } else {
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: UITableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if messageArray[indexPath.row].isAlert {
            let alertCell = messageTableView.dequeueReusableCell(withIdentifier: "alertMessageCell", for: indexPath) as! AlertMessageCell
//            alertCell.content.frame = CGRect(x: 0, y: 0, width: alertCell.frame.width, height: alertCell.frame.height)
//            alertCell.content.textAlignment = .center
            alertCell.content.text = messageArray[indexPath.row].content
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        messageTableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: Scrolling Methods
    func scrollToBottom() {
        if(needToScroll()) {
            let path = NSIndexPath(row: messageArray.count-1, section: 0)
            messageTableView.scrollToRow(at: path as IndexPath, at: .bottom, animated: true)
        }
    }
    /// Is the table view scrolled to the bottom or no?
    // NOTE: This doesn't work
    func didScrollToBottom() -> Bool {
        let distanceFromBottom = messageTableView.contentSize.height - messageTableView.contentOffset.y
        return distanceFromBottom <= messageTableView.frame.size.height
    }
    /// Do you need to scroll or no?
    func needToScroll() -> Bool {
        return messageTableView.contentSize.height > messageTableView.frame.size.height
    }
    
    // MARK: JoinGroupDelegate Methods
    func joinGroup(_ group: Group) {
        messageArray = [Message]()
        groupInformation = group
        UIView.setAnimationsEnabled(true)
        socket.emit("get_messages_on_start", group.id)
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
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goBackToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.delegate = self
            destinationVC.socket = socket
            destinationVC.justStarted = false
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Edit UIViewController transition left -> right
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.view.window?.layer.add(transition, forKey: nil)
    }
    /// Change the height based on content. If estimated height is wrong, then change height based on constraints
    func configureTableView() {
        messageTableView.rowHeight = UITableViewAutomaticDimension
        messageTableView.estimatedRowHeight = 120.0
    }
    @objc func tableViewTapped() {
        messageTextField.endEditing(true)
    }
}

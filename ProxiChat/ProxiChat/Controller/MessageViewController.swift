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
 TODO
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
 - when terminating app, request from database, if no results, then send - user has left the group
 - only send "user has left" message when NOT STARRED
 - save what the user wrote in textfield even when the app closes?
 
 BUGS
 - text view changing height doesn't perfectly shift, some overscrolling
 - table view doesn't perfectly shift the same amount of points as the keyboard
 - Alert message won't center??? - should I show to current user or no?
 - only display alert message if someone stars/favorites the group
 */

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, JoinGroupDelegate {

    /// 0 - GroupsViewController, 1 - StarredGroupsViewController
    var fromViewController = -1
    var groupInformation: Group!
    var socket: SocketIOClient?
    var messageArray: [Message] = [Message]()
    var lastLines = 1 // Saves the last number of line change
    let maxLines = 5 // 5 lines - max number of text view lines
    let placeholder = "Enter a message..."
    let placeholderColor: UIColor = UIColor.lightGray
    var typingHeight: CGFloat = 0 // Starting height of typing view - Only change in viewDidLoad
    let paddingTextView = Dimensions.getPoints(10) // Top and bottom padding of text view
    var startingContentHeight: CGFloat = 0 // Only change in viewDidLoad
    var lastContentHeight: CGFloat = 0
    var maxContentHeight: CGFloat = 0 // Max height of text view, Only change in viewDidLoad
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var dimView: UIView!
    @IBOutlet var coverStatusViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTableViewBottomConstraint: NSLayoutConstraint! // Same as typing view height
    @IBOutlet var messageTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageTextView: UITextView! // TODO: Add text view dimensions for responsiveness
    
    @IBOutlet var messageView: UIView!
    @IBOutlet var messageViewHeight: NSLayoutConstraint!
    @IBOutlet var messageViewBottomConstraint: NSLayoutConstraint! // Changed only when the table view content is overflowing
    
    @IBOutlet var infoView: UIView!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    @IBOutlet var typingView: UIView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    @IBOutlet var typingViewBottomConstraint: NSLayoutConstraint! // Changed only when table view content is not overflowing
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        
        // Make a fake placeholder in text view
        messageTextView.text = placeholder
        messageTextView.textColor = placeholderColor
        startingContentHeight = messageTextView.contentSize.height
        lastContentHeight = startingContentHeight
        maxContentHeight = CGFloat(floorf(Float(startingContentHeight + (messageTextView.font?.lineHeight)! * CGFloat(maxLines - 1))))
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        typingHeight = startingContentHeight + Dimensions.getPoints(20) // Relative to text view starting content size + 10 padding top + 10 padding bottom
        typingViewHeight.constant = typingHeight
        messageTableViewBottomConstraint.constant = typingViewHeight.constant
        coverStatusViewHeight.constant = UIApplication.shared.statusBarFrame.height
        
        eventHandlers()
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextView.delegate = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Initialize gestures
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeGroupInfo))
        dimView.addGestureRecognizer(dimTap)
        
        // Register nibs
        messageTableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "messageCell")
        
        messageTextView.keyboardType = .alphabet
        messageTextView.isScrollEnabled = true
        messageTextView.alwaysBounceVertical = false
        
        messageTableView.separatorStyle = .none
        messageViewHeight.constant = self.view.frame.height - UIApplication.shared.statusBarFrame.height - infoViewHeight.constant
        messageTableViewHeight.constant = messageViewHeight.constant - typingViewHeight.constant
        
        // Get messages - on response, join room
        // TODO: Paginate messages
        socket?.emit("get_messages_on_start", groupInformation.id)
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
        slideRightTransition()
        UIView.setAnimationsEnabled(false)
        
        // Check which view controller it came from
        switch fromViewController {
        case 0:
            performSegue(withIdentifier: "goBackToGroups", sender: self)
            break
        case 1:
            performSegue(withIdentifier: "goBackToStarredGroups", sender: self)
            break
        default:
            break
        }
        
        socket?.emit("leave_room", [
            "group_id": groupInformation.id,
            "username": UserData.username
            ])
    }
    
    @IBAction func showGroupInfo(_ sender: Any) {
        dimView.isUserInteractionEnabled = true
        UIView.animate(withDuration: Durations.showGroupInfoDuration) {
            self.dimView.alpha = 0.5
        }
    }
    
    @IBAction func sendPressed(_ sender: Any) {
        if !Validate.isInvalidInput(messageTextView.text!) && messageTextView.textColor != UIColor.lightGray {
            messageTextView.endEditing(true)
            messageTextView.isEditable = false
            sendButton.isEnabled = false
            
            // TODO: *** Get picture ***
            socket?.emit("send_message", [
                "username": UserData.username,
                "content": messageTextView.text!,
                "date_sent": String(describing: Date()),
                "group_id": groupInformation.id,
                "id": String(describing: UUID()),
                "picture": ""
                ])
            
            messageTextView.isEditable = true
            sendButton.isEnabled = true
            messageTextView.text = placeholder
            messageTextView.textColor = UIColor.lightGray
        }
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Realtime receiving messages
        socket?.on("receive_message") { (data, ack) in
            let messageObj = Message()
            
            messageObj.author = JSON(data[0])["author"].stringValue
            messageObj.content = JSON(data[0])["content"].stringValue
            messageObj.dateSent = JSON(data[0])["date_sent"].stringValue
            messageObj.id = JSON(data[0])["id"].stringValue
            messageObj.groupID = JSON(data[0])["group_id"].stringValue
            messageObj.picture = JSON(data[0])["picture"].stringValue
            
            self.messageArray.append(messageObj)
            
            self.configureTableView()
            self.messageTableView.reloadData()
            
            // If you are the sender
            if JSON(data[0])["author"].stringValue == UserData.username {
                self.scrollToBottom()
            }
        }
        
        // Get messages from database on join room
        socket?.on("get_messages_on_start_response") { (data, ack) in
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
                    messageObj.picture = message["picture"].stringValue
                    
                    self.messageArray.append(messageObj)
                }
                self.configureTableView()
                self.messageTableView.reloadData()
                
                // Join room after you get messages
                self.socket?.emit("join_room", [
                    "group_id": self.groupInformation.id,
                    "username": UserData.username
                    ])
                self.scrollToBottom()
            } else {
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        messageTableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: UITextViewDelegate Methods
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Change placeholder to actual text
        if textView.textColor == placeholderColor {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        // Change spaces and empty text to placeholder
        if Validate.isInvalidInput(textView.text!) {
            textView.text = placeholder
            textView.textColor = placeholderColor
        }
    }
    
    // TODO: Why is it over changing height?
    func textViewDidChange(_ textView: UITextView) {
        let lines = textView.contentSize.height / (textView.font?.lineHeight)! // Float
        let wholeLines = Int(floorf(Float(lines))) // Whole number
        
        // Check to see whether or not the number of lines changed
        if wholeLines != lastLines {
            
            // If adding text and greator than the max number of lines, then don't change the height
            if lastLines < maxLines || wholeLines < maxLines {
                
                // Get the change in height
                var changeInHeight: CGFloat = 0
                if wholeLines >= maxLines {
                    changeInHeight = maxContentHeight - lastContentHeight
                } else {
                    changeInHeight = textView.contentSize.height - lastContentHeight
                }
                
                if !UIView.areAnimationsEnabled {
                    UIView.setAnimationsEnabled(true)
                }
                UIView.animate(withDuration: Durations.textViewHeightDuration, animations: {
                    self.typingViewHeight.constant = self.typingViewHeight.constant + CGFloat(changeInHeight)
                })
                
                lastLines = wholeLines
                lastContentHeight = textView.contentSize.height
            }
        }
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
        // TODO: Check initialization
        UIView.setAnimationsEnabled(true)
        messageArray = [Message]()
        groupInformation = group
        groupTitle.text = group.title
        lastLines = 1
        messageTextView.text = placeholder
        messageTextView.textColor = UIColor.lightGray
        socket?.emit("get_messages_on_start", group.id)
    }
    
    // MARK: Keyboard (NotificationCenter) Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            // Get keyboard animation duration
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            // Get keyboard height
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            
            // Animate
            UIView.animate(withDuration: duration) {
                // Handle 3 scenarios
                let leftOverSpace = self.messageTableView.frame.height - self.messageTableView.contentSize.height
                if leftOverSpace > 0 {
                    if leftOverSpace < keyboardHeight + self.typingHeight {
                        self.messageTableViewBottomConstraint.constant = self.messageTableViewBottomConstraint.constant + (keyboardHeight - leftOverSpace)
                        self.typingViewBottomConstraint.constant = keyboardHeight
                    } else {
                        self.typingViewBottomConstraint.constant = keyboardHeight
                    }
                } else {
                    self.messageViewBottomConstraint.constant = keyboardHeight
                }
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            UIView.animate(withDuration: duration) {
                self.messageViewBottomConstraint.constant = 0
                self.typingViewBottomConstraint.constant = 0
                self.messageTableViewBottomConstraint.constant = Dimensions.getPoints(self.typingViewHeight.constant)
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
            destinationVC.username = UserData.username
            destinationVC.messageObj = self // If the user navigates to any other view controller, then set the socket = nil
            UserData.createNewMessageViewController = false
        } else if segue.identifier == "goBackToStarredGroups" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.delegate = self
            destinationVC.socket = socket
            destinationVC.messageObj = self // If the user navigates to any other view controller, then set the socket = nil
            UserData.createNewMessageViewController = false
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Edit UIViewController transition left -> right
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
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
    
    @objc func closeGroupInfo() {
        dimView.isUserInteractionEnabled = false
        UIView.animate(withDuration: Durations.showGroupInfoDuration) {
            self.dimView.alpha = 0
        }
    }
    
    @objc func tableViewTapped() {
        messageTextView.endEditing(true)
    }
}

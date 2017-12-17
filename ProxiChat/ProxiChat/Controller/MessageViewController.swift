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
    var lastNumOfLines: CGFloat = 1.82381823433138 // Saves the last number of line change
    var lastTextViewHeight: CGFloat! // Keep track of different in height change to change the messageTableViewHeight constraint also
    let maxNumOfLines: CGFloat = 5.8657937806874 // TODO: 5 lines - change this accordingly
    let placeholder = "Enter a message..."
    let placeholderColor: UIColor = UIColor.lightGray
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var messageTextView: UITextView!
    @IBOutlet var messageView: UIView!
    @IBOutlet var typingView: UIView!
    @IBOutlet var infoView: UIView!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var messageViewBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        eventHandlers()
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextView.delegate = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Trigger an action whenever the table view is tapped
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        
        // Register nibs
        messageTableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "messageCell")
        messageTableView.register(UINib(nibName: "AlertMessageCell", bundle: nil), forCellReuseIdentifier: "alertMessageCell")
        
        messageTextView.keyboardType = .alphabet
        // Make a fake placeholder
        messageTextView.text = placeholder
        messageTextView.textColor = placeholderColor
        lastTextViewHeight = messageTextView.contentSize.height
        messageTextView.frame.size = CGSize(width: messageTextView.frame.size.width, height: lastTextViewHeight)
        
        // TODO::::::::::::::::::::::::::::::: FIX THE HEIGHT RESPONSIVENESS ::::::::::::::::::::::::::::::::::
        messageTableView.separatorStyle = .none
        messageView.frame.size = CGSize(width: self.view.frame.size.width, height: self.view.frame.size.height - infoView.frame.size.height)
//        messageView.frame = CGRect(x: 0, y: typingView.frame.height, width: self.view.frame.height, height: self.view.frame.height - infoView.frame.height)
        messageTableView.frame.size = CGSize(width: messageView.frame.size.width, height: messageView.frame.size.height - typingView.frame.size.height)
        
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
        print("show group info")
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
            
            // If not alert and you are the sender
            if !isAlert && JSON(data[0])["author"].stringValue == UserData.username {
                self.scrollToBottom()
            }
        }
        
        // Get messages on join room
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
                    messageObj.isAlert = message["is_alert"].boolValue
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
    
    // MARK: UITableViewDelgate Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageArray.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if messageArray[indexPath.row].isAlert {
            let alertCell = messageTableView.dequeueReusableCell(withIdentifier: "alertMessageCell", for: indexPath) as! AlertMessageCell
            // TODO: Figure out why this isn't working
            alertCell.content.frame = CGRect(x: 0, y: 0, width: alertCell.frame.width, height: alertCell.frame.height)
            alertCell.content.textAlignment = .center
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
        if textView.text.split(separator: " ").count == 0 {
            textView.text = placeholder
            textView.textColor = placeholderColor
        }
    }
    // TODO: Figure out scrolling text view
    // TODO: Height does not change
    func textViewDidChange(_ textView: UITextView) {
        messageTextView.isScrollEnabled = true
        let numberOfLines = textView.contentSize.height / (textView.font?.lineHeight)!
//        print(String(Int(floorf(Float(numberOfLines)))) + " lines: " + String(describing: numberOfLines))
//        print(textView.contentSize.height)
        
        // If more than of equal to the max number of lines AND was less than the limit
//        if floorf(Float(numberOfLines)) >= floorf(Float(maxNumOfLines)) && floorf(Float(lastNumOfLines)) < floorf(Float(maxNumOfLines)) {
//            if floorf(Float(numberOfLines)) != floorf(Float(lastNumOfLines)) {
//                let maxHeightSize = (textView.font?.lineHeight)! * maxNumOfLines
//                let diff = maxHeightSize - lastTextViewHeight // Get difference between max height and last height
//                // If greater than max number of lines, then animate height to maxLine height
//                UIView.animate(withDuration: 0.1, animations: {
//                    self.typingView.frame.size = CGSize(width: self.typingView.frame.size.width, height: maxHeightSize)
//                    self.messageViewBottomConstraint.constant = self.messageViewBottomConstraint.constant + diff
//                    self.view.layoutIfNeeded()
//                })
//                lastNumOfLines = numberOfLines
//                lastTextViewHeight = textView.contentSize.height
//            }
//        } else if floorf(Float(numberOfLines)) < floorf(Float(maxNumOfLines)) {
//            if floorf(Float(numberOfLines)) != floorf(Float(lastNumOfLines)) {
////                let differenceInHeight = (floorf(Float(numberOfLines)) - floorf(Float(lastNumOfLines))) * Float((textView.font?.lineHeight)!)
//                let differenceInHeight = textView.contentSize.height - lastTextViewHeight // Get text view height change
//                UIView.animate(withDuration: 0.1, animations: {
//                    self.typingView.frame.size = CGSize(width: self.typingView.frame.size.width, height: self.typingView.frame.size.height + differenceInHeight)
//                    self.view.layoutIfNeeded()
//                })
//                lastNumOfLines = numberOfLines
//                lastTextViewHeight = textView.contentSize.height
//            }
//        }
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
        UIView.setAnimationsEnabled(true)
        messageArray = [Message]()
        groupInformation = group
        groupTitle.text = group.title
        lastNumOfLines = 1
        messageTextView.text = placeholder
        messageTextView.textColor = UIColor.lightGray
        lastTextViewHeight = (messageTextView.font?.lineHeight)!
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
                // Shift message view up
                self.messageViewBottomConstraint.constant = keyboardHeight
                self.view.layoutIfNeeded() // If something in the view changed, then redraw/rerender
            }
        }
    }
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            UIView.animate(withDuration: duration) {
                self.messageViewBottomConstraint.constant = 0
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
    @objc func tableViewTapped() {
        messageTextView.endEditing(true)
    }
}

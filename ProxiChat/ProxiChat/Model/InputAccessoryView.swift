//
//  InputAccessoryView.swift
//  ProxiChat
//
//  Created by Michael Hsu on 4/25/18.
//  Copyright © 2018 Michael Hsu. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class InputAccessoryView: UIView {
    
    var messageTextView: UITextView!
    var sendButton: UIButton!
    
    // Cached Properties
    var initialText = ""
    var initialTextColor = UIColor.black
    
    static var messageViewController: MessageViewController!
    
    override var intrinsicContentSize: CGSize {
        // Return height of the text view with one line if the keyboard is hidden
        guard let mvc = InputAccessoryView.messageViewController else { return CGSize(width: bounds.width, height: InputAccessoryView.messageViewController.heightTypingView )}
        if mvc.messageTableView.scrollIndicatorInsets.bottom == 0 || mvc.isKeyboardHidden {
            print("one line")
            return CGSize(width: bounds.width, height: InputAccessoryView.messageViewController.heightTypingView)
        }
        
        
        print("real content size")
        
        // TODO: This doesn't make it bounce, but how to start scrolling when it hits a certain number of lines?
        // If this can be figured out, then keep it - otherwise go back to an earlier commit
        let sizeToFitIn = CGSize(width: messageTextView.bounds.size.width, height: .greatestFiniteMagnitude)
        let newSize = messageTextView.sizeThatFits(sizeToFitIn)
        let newHeight = newSize.height
        return CGSize(width: bounds.width, height: newHeight)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        autoresizingMask = .flexibleHeight
        backgroundColor = UIColor.darkGray
        isHidden = true
        isUserInteractionEnabled = false
        
        messageTextView = UITextView()
        sendButton = UIButton(type: .system)
        InputAccessoryView.createViewAndInitialize(messageTextView, sendButton, InputAccessoryView.messageViewController, self)
    }
    
    /**
     Create a typing view from a text view and button. **Some parameters are passed by reference (inout)**, so you must have them as
     variables in your own class to be able to use them. When passing in arguments, prepend an "&" before the variable name.
     
     **WARNING: THIS DOES NOT HANDLE ADDING TO VIEW.** You must handle this yourself.
     
     This is used to initialize all typing view layouts and properties used for the actual `inputAccessoryView`.
     Sets up the fake `inputAccessoryView` the user sees on view load and the real `inputAccessoryView` with two separate calls.
     `inputAccess` is `nil` when invoked in MessageViewController, and both are non-nil when invoked in InputAccessoryView `init()`.
     
     - parameters:
        - messageTextView: The UITextView (user input) that is needed to be used.
        - sendButton: The button (that handles sending) that is needed to be used.
        - messageVC: MessageViewController instance passed in to handle layout and initializes typing view properties.
        - inputAccess: InputAccessoryView instance passed in.
     */
    static func createViewAndInitialize(_ messageTextView: UITextView, _ sendButton: UIButton, _ messageVC: MessageViewController?, _ inputAccess: InputAccessoryView?) {
        
        messageTextView.font = Font.getFont(16)
        messageTextView.keyboardType = .alphabet
        messageTextView.isScrollEnabled = false
        messageTextView.alwaysBounceVertical = false
        
        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        sendButton.titleLabel?.shadowColor = UIColor.clear
        
        // Initialize properties and layout here in MessageViewController ONLY
        if let mvc = messageVC, inputAccess == nil {
            messageTextView.text = " "
            mvc.startingContentHeight = messageTextView.contentSize.height // Get height of one line
            mvc.lastContentHeight = mvc.startingContentHeight
            mvc.maxContentHeight = CGFloat(floorf(Float(mvc.startingContentHeight + (messageTextView.font?.lineHeight)! * CGFloat(mvc.maxLines - 1))))
            
            // Get initial 1 line height of UITextView
            let sizeToFitIn = CGSize(width: messageTextView.bounds.size.width, height: .greatestFiniteMagnitude)
            let newSize = messageTextView.sizeThatFits(sizeToFitIn)
            let newHeight = newSize.height
            
            let keyExists = contentNotSent[mvc.groupInformation.title] != nil
            if !keyExists {
                mvc.fakeMessageTextView.text = mvc.placeholder
                mvc.fakeMessageTextView.textColor = mvc.placeholderColor
            } else {
                mvc.fakeMessageTextView.text = contentNotSent[mvc.groupInformation.title]
                mvc.fakeMessageTextView.textColor = UIColor.black
            }
            mvc.fakeTypingView.isUserInteractionEnabled = false
            
            mvc.heightTypingView = newHeight + mvc.paddingTextView * 2
            mvc.messageTableViewHeight.constant = mvc.messageViewHeight.constant - mvc.heightTypingView
            mvc.heightMessageTableView = mvc.messageTableViewHeight.constant
            
            // Set constraints
            mvc.fakeTypingViewHeight.constant = mvc.heightTypingView
            
            mvc.fakeMessageTextViewTop.constant = mvc.topBottomTextView
            mvc.fakeMessageTextViewBottom.constant = mvc.topBottomTextView
            mvc.fakeMessageTextViewLeft.constant = mvc.leftTextView
            mvc.fakeMessageTextViewWidth.constant = mvc.widthTextView
            
            mvc.fakeSendButtonWidth.constant = mvc.widthHeightSendButton
            mvc.fakeSendButtonHeight.constant = mvc.widthHeightSendButton
            mvc.fakeSendButtonBottom.constant = mvc.bottomSendButton
            mvc.fakeSendButtonRight.constant = mvc.rightSendButton
            
            messageViewController = mvc
        } else {
            // Initialize actual inputAccessoryView - InputAccessoryView
            // These two variables MUST NOT be nil
            guard let inputAccessView = inputAccess else { fatalError() }
            guard let mvc = messageVC else { fatalError() }
            
            messageTextView.translatesAutoresizingMaskIntoConstraints = false
            sendButton.translatesAutoresizingMaskIntoConstraints = false
            inputAccessView.addSubview(messageTextView)
            inputAccessView.addSubview(sendButton)
            
            // Message text view contraints
            messageTextView.bottomAnchor.constraint(equalTo: inputAccessView.bottomAnchor, constant: -mvc.fakeMessageTextViewBottom.constant).isActive = true
            messageTextView.topAnchor.constraint(equalTo: inputAccessView.topAnchor, constant: mvc.fakeMessageTextViewTop.constant).isActive = true
            messageTextView.leftAnchor.constraint(equalTo: inputAccessView.leftAnchor, constant: mvc.fakeMessageTextViewBottom.constant).isActive = true
            messageTextView.widthAnchor.constraint(equalToConstant: mvc.fakeMessageTextViewWidth.constant).isActive = true
            
            // Observers
            NotificationCenter.default.addObserver(mvc, selector: #selector(mvc.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            NotificationCenter.default.addObserver(mvc, selector: #selector(mvc.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            
            if !mvc.observed {
                // Add an observer to track whenever the contentSize has changed
                messageTextView.addObserver(mvc, forKeyPath: "contentSize", options: .new, context: nil)
                mvc.observed = true
            }
            sendButton.addTarget(mvc, action: #selector(mvc.sendPressed(_:)), for: .touchUpInside)
            
            // Send button contraints
            sendButton.heightAnchor.constraint(equalToConstant: mvc.fakeSendButtonHeight.constant).isActive = true
            sendButton.widthAnchor.constraint(equalToConstant: mvc.fakeSendButtonWidth.constant).isActive = true
            sendButton.bottomAnchor.constraint(equalTo: inputAccessView.bottomAnchor, constant: -mvc.fakeSendButtonBottom.constant).isActive = true
            sendButton.rightAnchor.constraint(equalTo: inputAccessView.rightAnchor, constant: -mvc.fakeSendButtonRight.constant).isActive = true
            
            messageTextView.delegate = mvc
            messageTextView.text = mvc.fakeMessageTextView.text
            messageTextView.textColor = mvc.fakeMessageTextView.textColor
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

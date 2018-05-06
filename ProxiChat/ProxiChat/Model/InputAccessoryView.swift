//
//  InputAccessoryView.swift
//  ProxiChat
//
//  Created by Michael Hsu on 4/25/18.
//  Copyright © 2018 Michael Hsu. All rights reserved.
//

import Foundation
import UIKit

// https://stackoverflow.com/questions/25816994/changing-the-frame-of-an-inputaccessoryview-in-ios-8
class InputAccessoryView: UIView, UITextViewDelegate {
    
    let messageTextView = UITextView()
    
    override var intrinsicContentSize: CGSize {
        let textSize = messageTextView.sizeThatFits(CGSize(width: messageTextView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: bounds.width, height: textSize.height)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        autoresizingMask = .flexibleHeight
        backgroundColor = UIColor.darkGray
    }
    
    func initLayout(groupInformation: Group, fakeMessageTextView: UITextView) {
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

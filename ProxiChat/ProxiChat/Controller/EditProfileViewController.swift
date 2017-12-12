//
//  EditProfileViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/11/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class EditProfileViewController: UIViewController {
    
    var socket: SocketIOClient?
    var username = ""
    var row = -1

    @IBOutlet var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Change view for the row chosen
        switch row {
        case 1:
            titleLabel.text = "Change Password"
            break
        case 2:
            titleLabel.text = "Edit Bio"
            break
        case 3:
            titleLabel.text = "Change Email"
            break
        default:
            break
        }
        
        self.view.layoutIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
    @IBAction func close(_ sender: UIButton) {
        slideRightTransition()
        self.dismiss(animated: false, completion: nil)
    }
    
    // MARK: Miscellaneous Methods
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.view.window?.layer.add(transition, forKey: nil)
    }
}

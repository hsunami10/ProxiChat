//
//  WelcomeViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD

class WelcomeViewController: UIViewController {
    
    @IBOutlet var signUpButton: UIButton!
    @IBOutlet var logInButton: UIButton!
    @IBOutlet var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.text = ""
        
        // Only delete anonymous users, other users shouldn't happen
        // Sign up and Log in SHOULD always have currentUser as nil
//        if Auth.auth().currentUser != nil {
//            if (Auth.auth().currentUser?.isAnonymous)! {
//                Auth.auth().currentUser?.delete(completion: { (error) in
//                    if error != nil {
//                        SVProgressHUD.showError(withStatus: error!.localizedDescription)
//                    }
//                })
//            } else {
//                try! Auth.auth().signOut()
//                SVProgressHUD.showError(withStatus: AlertMessages.authError)
//            }
//        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Segue prepare
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
    }
}



//
//  WelcomeViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

class WelcomeViewController: UIViewController {
    
    var socket: SocketIOClient?
    
    @IBOutlet var signUpButton: UIButton!
    @IBOutlet var logInButton: UIButton!
    @IBOutlet var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.text = ""
        
        if socket == nil {
            socket = SocketIOClient(socketURL: URL(string: "http://localhost:3000")!)
            // TODO: Add reconnecting later - socket.reconnect()
            socket?.connect(timeoutAfter: 5.0) {
                self.signUpButton.isEnabled = false
                self.logInButton.isEnabled = false
                self.statusLabel.text = "Connection Failed."
                
                SVProgressHUD.showError(withStatus: "Connection Failed.")
                // TODO: Add UIAlertController to reconnect and show failure.
            }
        }
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
        if segue.identifier == "goToSignUp" {
            let destinationVC = segue.destination as! SignUpViewController
            destinationVC.socket = socket
        } else if segue.identifier == "goToLogIn" {
            let destinationVC = segue.destination as! LogInViewController
            destinationVC.socket = socket
        }
    }
}



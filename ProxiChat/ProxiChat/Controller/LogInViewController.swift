//
//  LogInViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

class LogInViewController: UIViewController {
    
    var socket: SocketIOClient?

    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = " "
        eventHandlers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func eventHandlers() {
        socket?.on("sign_in_response", callback: { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                // Save log in
                UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
                UserDefaults.standard.set(self.usernameTextField.text!, forKey: "proxiChatUsername")
                UserDefaults.standard.synchronize()
                
                SVProgressHUD.dismiss()
                self.performSegue(withIdentifier: "goToGroups", sender: self)
            } else {
                SVProgressHUD.dismiss()
                self.errorLabel.text = error_msg
            }
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            destinationVC.username = usernameTextField.text!
            destinationVC.justStarted = true
        }
    }
    
    @IBAction func logIn(_ sender: Any) {
        let username = usernameTextField.text!
        let password = passwordTextField.text!
        
        if username.split(separator: " ").count != 1 || password.split(separator: " ").count != 1 {
            errorLabel.text = "Invalid username and/or password."
        } else {
            SVProgressHUD.show()
            socket?.emit("sign_in", username, password)
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

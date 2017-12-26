//
//  RegisterVIewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    var socket: SocketIOClient?
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var repeatPasswordTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = " "
        eventHandlers()
        emailTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        socket?.on("sign_up_response", callback: { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            // Successfully signed in?
            if success {
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
    
    // MARK: UITextField Delegate Methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        signUp(usernameTextField.text!, passwordTextField.text!, repeatPasswordTextField.text!, emailTextField.text!)
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            destinationVC.username = usernameTextField.text!
        }
    }
    
    // MARK: IBOutlet Actions
    /// Checks for valid inputs, then sends accordingly.
    @IBAction func submitSignUp(_ sender: Any) {
        signUp(usernameTextField.text!, passwordTextField.text!, repeatPasswordTextField.text!, emailTextField.text!)
    }
    
    @IBAction func goBack(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Notification Center Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            UserDefaults.standard.set(keyboardHeight, forKey: "proxiChatKeyboardHeight")
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Validates all inputs. If all pass, then registers the user.
    func signUp(_ username: String, _ password: String, _ passwordRetype: String, _ email: String) {
        // TODO: Optional: Add requirements to password?
        if !Validate.isOneWord(username) || !Validate.isOneWord(password) || !Validate.isOneWord(passwordRetype) {
            errorLabel.text = "Invalid username and/or password."
        } else if password != passwordRetype {
            errorLabel.text = "Passwords do not match."
        } else if !Validate.isValidEmail(email) {
            errorLabel.text = "Email address not valid."
        } else {
            SVProgressHUD.show()
            socket?.emit("sign_up", username, password, email)
        }
    }
}

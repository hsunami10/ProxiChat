//
//  RegisterVIewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import Firebase

/*
 TODO
 
 BUGS
 - fix checking for existing username - observeSingleEvent always runs after???
 */

class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var repeatPasswordTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = " "
        emailTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            UserData.username = usernameTextField.text!
            
            // Save log in
            UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
            UserDefaults.standard.set(self.usernameTextField.text!, forKey: "proxiChatUsername")
            UserDefaults.standard.synchronize()
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
            let usersDB = Database.database().reference().child(FirebaseNames.users)
            usersDB
                .queryOrdered(byChild: "email")
                .queryEqual(toValue: email)
                .observeSingleEvent(of: .value, with: { (snapshot) in
                    // Check if email exists
                    if snapshot.childrenCount != 0 {
                        SVProgressHUD.dismiss()
                        self.errorLabel.text = "Email already exists."
                        return
                    }
                    self.findUsername(username, password, email)
            })
        }
    }
    
    /// Find a username with the specified string in the firebase database. If it doesn't exist, then create the user and log in.
    func findUsername(_ username: String, _ password: String, _ email: String) {
        let usersDB = Database.database().reference().child(FirebaseNames.users)
        usersDB
            .queryOrderedByKey()
            .queryEqual(toValue: username)
            .observeSingleEvent(of: .value) { (snapshot) in
                // Check if username exists
                if snapshot.childrenCount != 0 {
                    SVProgressHUD.dismiss()
                    self.errorLabel.text = "Username already taken."
                    return
                }
                
                // Email registration
                Auth.auth().createUser(withEmail: email, password: password, completion: { (user, error) in
                    if error != nil {
                        print(error!.localizedDescription)
                        SVProgressHUD.dismiss()
                        self.errorLabel.text = error!.localizedDescription
                    } else {
                        // Store default user data
                        usersDB.child(username).setValue([
                            "email" : email,
                            "password" : password,
                            "radius" : 40,
                            "is_online" : true,
                            "latitude" : 0,
                            "longitude" : 0,
                            "bio" : "",
                            "picture" : "",
                            ])
                    }
                })
        }
    }
}

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
 */

// Sign into anonymous account to allow temporary access
class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    private var canSignUp = false
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var repeatPasswordTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        errorLabel.text = " "
        emailTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        UserData.connected = false
        
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { (user, error) in
                if error != nil {
                    print(error!.localizedDescription)
                    SVProgressHUD.showError(withStatus: AlertMessages.authError)
                } else {
                    print("successfully signed in anon")
                    self.canSignUp = true
                }
            }
        } else {
            if (Auth.auth().currentUser?.isAnonymous)! {
                print("existing anon")
                self.canSignUp = true
            } else {
                SVProgressHUD.showError(withStatus: AlertMessages.authError)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
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
            UserData.signedIn = true
            
            // Save log in
            UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
            UserDefaults.standard.set(UserData.username, forKey: "proxiChatUsername")
            UserDefaults.standard.set(UserData.password, forKey: "proxiChatPassword")
            UserDefaults.standard.set(UserData.email, forKey: "proxiChatEmail")
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
        if !canSignUp {
            SVProgressHUD.showError(withStatus: AlertMessages.authError)
            return
        }
        
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
        
        // Cache anonymous user to delete when sign up / register is successful
        guard let anonUser = Auth.auth().currentUser else {
            SVProgressHUD.dismiss()
            SVProgressHUD.showError(withStatus: AlertMessages.authError)
            return
        }
        
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
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: error!.localizedDescription)
                        self.errorLabel.text = error!.localizedDescription
                    } else {
                        Auth.auth().currentUser?.createProfileChangeRequest().displayName = username
                        Auth.auth().currentUser?.createProfileChangeRequest().commitChanges(completion: { (error) in
                            if error != nil {
                                print(error!.localizedDescription)
                                
                                // Failed to change name, so undo registration (delete user), and sign in anonymously again
                                Auth.auth().currentUser?.delete(completion: { (error) in
                                    if error != nil {
                                        SVProgressHUD.dismiss()
                                        SVProgressHUD.showError(withStatus: error!.localizedDescription)
                                    } else {
                                        Auth.auth().signInAnonymously(completion: { (user, error) in
                                            SVProgressHUD.dismiss()
                                            if error != nil {
                                                SVProgressHUD.showError(withStatus: error!.localizedDescription)
                                            } else {
                                                // If successfully signed in anonymously, then don't do anything - prompt try again.
                                                SVProgressHUD.showSuccess(withStatus: "Please try again.")
                                            }
                                        })
                                    }
                                })
                            } else {
                                // Store default user data
                                usersDB.child(username).setValue([
                                    "email" : email,
                                    "password" : password,
                                    "radius" : 150,
                                    "is_online" : true,
                                    "latitude" : 0,
                                    "longitude" : 0,
                                    "bio" : "",
                                    "picture" : "",
                                    ], withCompletionBlock: { (error, ref) in
                                        // Delete anonymous user
                                        anonUser.delete(completion: { (error) in
                                            if error != nil {
                                                SVProgressHUD.dismiss()
                                                SVProgressHUD.showError(withStatus: error!.localizedDescription)
                                            } else {
                                                SVProgressHUD.dismiss()
                                                UserData.username = username
                                                UserData.email = email
                                                UserData.password = password
                                                
                                                self.performSegue(withIdentifier: "goToGroups", sender: self)
                                            }
                                        })
                                })
                            }
                        })
                    }
                })
        }
    }
}

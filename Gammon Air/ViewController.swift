//
//  ViewController.swift
//  Gammon Air
//
//  Created by Rolf Locher on 4/30/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import UIKit
import AudioToolbox
import Firebase

protocol HomeScreenDelegate : class {
    // unused
}

class ViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, BoardViewDelegate {
    
    @IBOutlet var hostButton: UIVisualEffectView!
    
    @IBOutlet var joinButton: UIVisualEffectView!
    
    @IBOutlet var compButton: UIVisualEffectView!
    
    @IBOutlet var hostMenu: UIVisualEffectView!
    
    @IBOutlet var hostReturnButton: UIImageView!
    
    @IBOutlet var hostNameField: UITextField!
    
    @IBOutlet var hostRedButton: UIImageView!
    
    @IBOutlet var hostBlackButton: UIImageView!
    
    @IBOutlet var menuPan: NSLayoutConstraint!
    
    @IBOutlet var menuContainer: UIView!
    
    @IBOutlet var menuVertPan: NSLayoutConstraint!
    
    @IBOutlet var hostWaitingScreen: UIVisualEffectView!
    
    @IBOutlet var hostWaitingCancelButton: UIImageView!
    
    @IBOutlet var joinMenu: UIVisualEffectView!
    
    @IBOutlet var joinTable: UITableView!
    
    @IBOutlet var joinReturnButton: UIImageView!
    
    var db : Firestore? = nil
    
    var gameID = String()
    var hostObserver : ListenerRegistration? = nil
    var localIDs = [String]()
    var localNames = [String]()
    var shouldKill = false {
        didSet {
            self.hostObserver?.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        db = Firestore.firestore()
        
        let buttonRadius : CGFloat = 15.0
        hostButton.layer.cornerRadius = buttonRadius
        hostButton.clipsToBounds = true
        joinButton.layer.cornerRadius = buttonRadius
        joinButton.clipsToBounds = true
        compButton.layer.cornerRadius = buttonRadius
        compButton.clipsToBounds = true
        
        hostRedButton.layer.cornerRadius = 8.0
        hostBlackButton.layer.cornerRadius = 8.0
        hostRedButton.isUserInteractionEnabled = true
        hostBlackButton.isUserInteractionEnabled = true
        
        hostWaitingScreen.alpha = 0.0
        
        hostMenu.layer.cornerRadius = buttonRadius
        hostMenu.clipsToBounds = true
        joinMenu.layer.cornerRadius = buttonRadius
        joinMenu.clipsToBounds = true
        joinTable.layer.cornerRadius = 8.0
        joinTable.clipsToBounds = true
        
        let hostTap = UITapGestureRecognizer(target: self, action: #selector(hostTapped))
        hostButton.addGestureRecognizer(hostTap)
        hostButton.isUserInteractionEnabled = true
        
        let joinTap = UITapGestureRecognizer(target: self, action: #selector(joinTapped))
        joinButton.addGestureRecognizer(joinTap)
        joinButton.isUserInteractionEnabled = true
        
        let compTap = UITapGestureRecognizer(target: self, action: #selector(compTapped))
        compButton.addGestureRecognizer(compTap)
        compButton.isUserInteractionEnabled = true
        
        let hostReturnTap = UITapGestureRecognizer(target: self, action: #selector(hostReturnTapped))
        hostReturnButton.addGestureRecognizer(hostReturnTap)
        hostReturnButton.isUserInteractionEnabled = true
        
        let hostRedTap = UITapGestureRecognizer(target: self, action: #selector(hostRedTapped))
        hostRedButton.addGestureRecognizer(hostRedTap)
        hostRedButton.isUserInteractionEnabled = true
        
        let hostBlackTap = UITapGestureRecognizer(target: self, action: #selector(hostBlackTapped))
        hostBlackButton.addGestureRecognizer(hostBlackTap)
        hostBlackButton.isUserInteractionEnabled = true
        
        let hostWaitingCancelTap = UITapGestureRecognizer(target: self, action: #selector(hostWaitingCancelTapped))
        hostWaitingCancelButton.addGestureRecognizer(hostWaitingCancelTap)
        hostWaitingCancelButton.isUserInteractionEnabled = true
        
        let joinReturnTap = UITapGestureRecognizer(target: self, action: #selector(joinReturnTapped))
        joinReturnButton.addGestureRecognizer(joinReturnTap)
        joinReturnButton.isUserInteractionEnabled = true
   
        hostNameField.delegate = self
        hostNameField.returnKeyType = .done
        
        joinTable.delegate = self
        joinTable.dataSource = self
        
        Auth.auth().signInAnonymously { (result, error) in
            if let res = result {
                print(res)
                let db = Firestore.firestore()
                db.collection("games").addSnapshotListener({ (snapshot, error) in
                    if snapshot?.count == 0 {
                        return
                    }
                    var IDList = [String]()
                    for doc in snapshot!.documents {
                        if (doc.data()["name"]) == nil {
                            return
                        }
                        IDList.append(doc.documentID)
                        if !self.localIDs.contains(doc.documentID) {
                            self.localIDs.append(doc.documentID)
                            self.localNames.append(doc.data()["name"] as! String)
                            self.joinTable.insertRows(at: [IndexPath(row: self.localNames.count-1, section: 0)], with: .fade)
                        }
                    }
                    for id in self.localIDs {
                        if !IDList.contains(id) {
                            let killIndex = self.localIDs.firstIndex(of: id)!
                            self.localNames.remove(at: killIndex)
                            self.localIDs.remove(at: killIndex)
                            self.joinTable.deleteRows(at: [IndexPath(row: killIndex, section: 0)], with: .fade)
                        }
                    }
                })
                
            }
            else {
                print( error! )
            }
        }
        
    }
    
    func dismissBoard() {
        self.dismiss(animated: true) {
            print("we back")
        }
    }
    
    @objc func hostRedTapped () {
        if hostNameField.text == "" {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }
        self.hostWaitingScreen.isHidden = false
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 1
        }) { (val) in
            
        }
        let db = Firestore.firestore()
        var ref : DocumentReference? = nil
        ref = db.collection("games").addDocument(data: [
            "open" : true,
            "hostColor" : "white",
            "name" : hostNameField.text!
        ]) { (val) in
            self.gameID = ref!.documentID
            
            self.hostObserver = db.collection("games").document(self.gameID).addSnapshotListener({ (snapshot, error) in
                if snapshot?.data()?["open"] as! Bool == true {
                    return
                }
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
                vc.gameID = self.gameID
                vc.color = "white"
                vc.isHost = true
                self.present(vc, animated: true, completion: nil)
                self.shouldKill = true
            })
        }
    }
    
    @objc func hostBlackTapped () {
        if hostNameField.text == "" {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }
        self.hostWaitingScreen.isHidden = false
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 1
        }) { (val) in
            
        }
        let db = Firestore.firestore()
        var ref : DocumentReference? = nil
        ref = db.collection("games").addDocument(data: [
            "open" : true,
            "hostColor" : "black",
            "name" : hostNameField.text!
        ]) { (val) in
            self.gameID = ref!.documentID
            
            self.hostObserver = db.collection("games").document(self.gameID).addSnapshotListener({ (snapshot, error) in
                if snapshot?.data()?["open"] as! Bool == true {
                    return
                }
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
                vc.gameID = self.gameID
                vc.color = "black"
                vc.isHost = true
                self.present(vc, animated: true, completion: nil)
                self.shouldKill = true
            })
        }
    }
    
    @objc func hostWaitingCancelTapped () {
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 0
        }) { (val) in
            self.hostWaitingScreen.isHidden = true
        }
        let db = Firestore.firestore()
        self.hostObserver?.remove()
        db.collection("games").document(gameID).delete()
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == hostNameField {
            menuVertPan.constant = -150
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveLinear], animations: {
                self.view.layoutIfNeeded()
            }) { (val) in
                print("k")
            }
            
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == hostNameField {
            menuVertPan.constant = 0
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveLinear], animations: {
                self.view.layoutIfNeeded()
            }) { (val) in
                print("k")
            }
            hostNameField.resignFirstResponder()
        }
        return true
    }

    @objc func hostTapped() {
        self.menuPan.constant = 23
        UIView.animate(withDuration: 0.7) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func joinTapped() {
        self.menuPan.constant = -698
        UIView.animate(withDuration: 0.7) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func compTapped() {
        
    }
    
    @objc func joinReturnTapped() {
        UIView.animate(withDuration: 0.7, animations: {
            self.menuPan.constant = -325
            self.view.layoutIfNeeded()
        }) { (val) in
        }
    }
    
    @objc func hostReturnTapped() {
        
        if hostNameField.isFirstResponder {
            menuVertPan.constant = 0
            hostNameField.resignFirstResponder()
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveLinear], animations: {
                self.view.layoutIfNeeded()
            }) { (val) in
                
                UIView.animate(withDuration: 0.7, animations: {
                    self.menuPan.constant = -325
                    self.view.layoutIfNeeded()
                }) { (val) in
                    self.hostNameField.text = ""
                }
            }
            
        }
        else {
            UIView.animate(withDuration: 0.7, animations: {
                self.menuPan.constant = -325
                self.view.layoutIfNeeded()
            }) { (val) in
                self.hostNameField.text = ""
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return localIDs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! JoinTableViewCell
        cell.nameLabel.text = localNames[indexPath.row]
        cell.id = localIDs[indexPath.row]
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = (self.joinTable.cellForRow(at: indexPath) as! JoinTableViewCell).id
//        db?.collection("games").document(id).getDocument { (snapshot, error) in
//            var nextColor = String()
//            var nextDice = Int.random(in: 1..<6)
//            if nextDice > snapshot?.data()?["dice0"] as! Int {
//                if snapshot?.data()?["hostColor"] as! String == "black" {
//                    nextColor = "white"
//                }
//                else {
//                    nextColor = "black"
//                }
//            }
//            else {
//                if snapshot?.data()?["hostColor"] as! String == "black" {
//                    nextColor = "black"
//                }
//                else {
//                    nextColor = "white"
//                }
//            }
//
        self.db?.collection("games").document(id).setData([
            "open" : false
            ], merge: true)
        self.db?.collection("games").document(id).getDocument(completion: { (snapshot, error) in
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
            vc.gameID = id
            if snapshot?.data()?["hostColor"] as! String == "white" {
                vc.color = "black"
            }
            else {
                vc.color = "white"
            }
            vc.isHost = false
            self.present(vc, animated: true, completion: nil)
        })
        
        
            
//        }
        
        
        
        
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("yes")
    }
}


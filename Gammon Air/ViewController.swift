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
import ContactsUI

protocol HomeScreenDelegate : class {
    // unused
}

class ViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, BoardViewDelegate, CNContactPickerDelegate, MessagingDelegate {
    
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
    
    @IBOutlet var phoneEntryView: UIView!
    
    @IBOutlet var phoneEntryField: UITextField!
    
    @IBOutlet var inviteRedBox: UIImageView!
    
    @IBOutlet var inviteBlackBox: UIImageView!
    
    @IBOutlet var inviteChoiceView: UIView!
    
    @IBOutlet var notificationBottom: NSLayoutConstraint!
    
    @IBOutlet var notificationView0: NotificationView!
    
    
    
    var db : Firestore? = nil
    
    var uid = String()
    var gameID = String()
    var token = String()
    var hostObserver : ListenerRegistration? = nil
    var joinObserver : ListenerRegistration? = nil
    
    var targetPhone = String()
    var localIDs = [String]()
    var localNames = [String]()
    var shouldKill = false {
        didSet {
            self.hostObserver?.remove()
            self.joinObserver?.remove()
        }
    }
    var isReturning = false {
        didSet {
            if isReturning == true {
                setupJoinObserver()
                isReturning = false
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        db = Firestore.firestore()
        
        hostWaitingScreen.alpha = 0.0
        
        let buttonRadius : CGFloat = 15.0
        hostButton.clipRound(buttonRadius)
        joinButton.clipRound(buttonRadius)
        compButton.clipRound(buttonRadius)
        
        hostRedButton.clipRound(8.0)
        hostBlackButton.clipRound(8.0)
        
        inviteBlackBox.clipRound(10.0)
        inviteRedBox.clipRound(10.0)
        
        hostMenu.clipRound(buttonRadius)
        joinMenu.clipRound(buttonRadius)
        joinTable.clipRound(8.0)
        
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
        
        let inviteRedTap = UITapGestureRecognizer(target: self, action: #selector(inviteRedTapped))
        inviteRedBox.addGestureRecognizer(inviteRedTap)
        inviteRedBox.isUserInteractionEnabled = true
        
        let inviteBlackTap = UITapGestureRecognizer(target: self, action: #selector(inviteBlackTapped))
        inviteBlackBox.addGestureRecognizer(inviteBlackTap)
        inviteBlackBox.isUserInteractionEnabled = true
        
        let notiAcceptTap = UITapGestureRecognizer(target: self, action: #selector(notiAcceptTapped))
        notificationView0.acceptButton.addGestureRecognizer(notiAcceptTap)
        notificationView0.acceptButton.isUserInteractionEnabled = true
        
        let notiDeclineTap = UITapGestureRecognizer(target: self, action: #selector(notiDeclineTapped))
        notificationView0.declineButton.addGestureRecognizer(notiDeclineTap)
        notificationView0.declineButton.isUserInteractionEnabled = true
        
        hostNameField.delegate = self
        hostNameField.returnKeyType = .done
        
        joinTable.delegate = self
        joinTable.dataSource = self
        
        phoneEntryField.delegate = self
        phoneEntryField.returnKeyType = .done
        
        Auth.auth().signInAnonymously { (result, error) in
            if let data = result {
                self.uid = data.user.uid
                self.setupJoinObserver()
            }
            else {
                print( error! )
            }
        }
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = false
        
        let db = Firestore.firestore()
        db.settings = settings
        
        Messaging.messaging().delegate = self
        InstanceID.instanceID().instanceID { (result, error) in
            if let error = error {
                print("Error fetching remote instance ID: \(error)")
            } else if let result = result {
                print("Remote instance ID token: \(result.token)")
                self.token = result.token
            }
        }
    }
    
    @objc func notiAcceptTapped() {
        hideNotification()
        let id = notificationView0.gameID
        self.db?.collection("games").document(id).setData([
            "joined" : true
            ], merge: true)
        self.db?.collection("games").document(id).getDocument(completion: { (snapshot, error) in
            self.joinObserver?.remove()
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
            vc.gameID = id
            if snapshot?.data()?["hostColor"] == nil {
                self.joinTable.reloadData()
                return
            }
            else if snapshot?.data()?["hostColor"] as! String == "white" {
                vc.color = "black"
            }
            else {
                vc.color = "white"
            }
            self.gameID = id
            self.setJoinedGame(color: vc.color)
            vc.isHost = false
            self.present(vc, animated: true, completion: nil)
        })
    }
    
    @objc func notiDeclineTapped() {
        hideNotification()
        let id = notificationView0.gameID
        self.db?.collection("games").document(id).setData([
            "declined" : true
            ], merge: true)
    }
    
    func hideNotification() {
        UIView.animate(withDuration: 0.7, animations: {
            self.notificationBottom.constant = 0
            self.view.layoutIfNeeded()
        }) { (val) in
        }
    }
    
    func showNotification(gameID: String, hostName: String, hostColor: String) {
        UIView.animate(withDuration: 0.7, animations: {
            self.notificationBottom.constant = -150
            self.notificationView0.gameID = gameID
            self.notificationView0.titleLabel.text = "\(hostName) invited you to play Gammon!"
            self.view.layoutIfNeeded()
        }) { (val) in
        }
    }
    
    @objc func inviteRedTapped() {
        inviteWithColor(color: "white")
    }
    
    @objc func inviteBlackTapped() {
        inviteWithColor(color: "black")
    }
    
    func inviteWithColor( color: String ) {
        
        self.hostWaitingScreen.isHidden = false
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 1
        }) { (val) in
            
        }
        var ref : DocumentReference? = nil
        ref = db?.collection("games").addDocument(data: [
            "open" : false,
            "joined" : false,
            "hostColor" : color,
            "name" : hostNameField.text!
        ]) { (val) in
            self.gameID = ref!.documentID
            
            self.db?.collection("gameInvites").document().setData([
                "toPhone" : self.targetPhone,
                "hostColor" : color,
                "from" : UIDevice.current.name,
                "gameID" : self.gameID
                ], merge: true)
            
            self.hostObserver = self.db?.collection("games").document(self.gameID).addSnapshotListener({ (snapshot, error) in
                if snapshot?.data()?["declined"] as? Bool != nil && snapshot?.data()?["declined"] as! Bool == true {
                    self.shouldKill = true
                    UIView.animate(withDuration: 0.7, animations: {
                        self.menuContainer.alpha = 1
                        self.hostWaitingScreen.alpha = 0
                    }, completion: { (val) in
                        self.hostWaitingScreen.isHidden = true
                    })
                    return
                }
                if snapshot?.data()?["joined"] as? Bool != nil && snapshot?.data()?["joined"] as! Bool == false {
                    return
                }
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
                vc.gameID = self.gameID
                vc.color = color
                vc.isHost = true
                self.present(vc, animated: true, completion: nil)
                self.setJoinedGame(color: color)
                self.shouldKill = true
                UIView.animate(withDuration: 0.7) {
                    self.menuContainer.alpha = 1
                }
            })
        }
        
        
        
        UIView.animate(withDuration: 0.7, animations: {
            self.inviteChoiceView.alpha = 0
        }) { (val) in
            self.inviteChoiceView.isHidden = true
        }
    }
    
    @objc func compTapped() {
        db?.collection("users").document(self.uid).getDocument(completion: { (snapshot, error) in
            if let phone = snapshot?.data()?["phone"] as? String {
                self.showContacts()
            }
            else {
                self.phoneEntryView.isHidden = false
                UIView.animate(withDuration: 0.7, animations: {
                    self.phoneEntryView.alpha = 1
                }, completion: { (val) in
                    
                })
            }
        })
    }
    
    func showContacts() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        self.present(contactPicker, animated: true, completion: nil)
        UIView.animate(withDuration: 0.7) {
            self.menuContainer.alpha = 0
        }
        
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if contact.phoneNumbers.count == 0 {
            return
        }
        var phoneFormat = (contact.phoneNumbers.first?.value)!.stringValue
        phoneFormat = phoneFormat.replacingOccurrences(of: " ", with: "")
        phoneFormat = phoneFormat.replacingOccurrences(of: "+", with: "")
        phoneFormat = phoneFormat.replacingOccurrences(of: "-", with: "")
        phoneFormat = phoneFormat.replacingOccurrences(of: "(", with: "")
        phoneFormat = phoneFormat.replacingOccurrences(of: ")", with: "")
        if phoneFormat.first! == "1" || phoneFormat.first! == "0" {
            phoneFormat.removeFirst()
        }
        print("contact phone: \(phoneFormat)")
        targetPhone = phoneFormat
        
        self.inviteChoiceView.isHidden = false
        self.view.layoutIfNeeded()
        print("alpha = \(inviteChoiceView.alpha)")
        UIView.animate(withDuration: 1.5) {
            self.inviteChoiceView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        UIView.animate(withDuration: 0.7) {
            self.menuContainer.alpha = 1
        }
    }
    
    func checkForPreviousGame() {
        db?.collection("users").document(self.uid).getDocument(completion: { (snapshot, error) in
            if let gameID = snapshot?.data()?["game"] as? String {
                self.db?.collection("games").document(gameID).getDocument(completion: { (gameSnap, gameError) in
                    if gameSnap?.data()?["turn"] as? String != nil {
                        let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
                        vc.gameID = gameID
                        vc.color = snapshot?.data()?["color"] as! String
                        vc.isHost = (gameSnap?.data()?["hostColor"] as! String) == vc.color
                        self.present(vc, animated: true, completion: nil)
                        self.shouldKill = true
                        return
                    }
                    else {
                        //self.db?.collection("users").document(self.uid).delete()
                    }
                })
            }
            else {
                //self.db?.collection("users").document(self.uid).delete()
            }
        })
    }
    
    func dismissBoard() {
        self.dismiss(animated: true)
    }
    
    func setJoinedGame(color : String) {
        db?.collection("users").document(self.uid).setData(["game": self.gameID, "color": color], merge: true)
    }
    
    func hostGame (color: String) {
        menuVertPan.constant = 0
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveLinear], animations: {
            self.view.layoutIfNeeded()
        }) { (val) in
            print("k")
        }
        hostNameField.resignFirstResponder()
        self.hostWaitingScreen.isHidden = false
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 1
        }) { (val) in
            
        }
        var ref : DocumentReference? = nil
        ref = db?.collection("games").addDocument(data: [
            "open" : true,
            "hostColor" : color,
            "name" : hostNameField.text!
        ]) { (val) in
            self.gameID = ref!.documentID
            
            self.hostObserver = self.db?.collection("games").document(self.gameID).addSnapshotListener({ (snapshot, error) in
                if snapshot?.data()?["open"] as? Bool != nil && snapshot?.data()?["open"] as! Bool == true {
                    return
                }
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
                vc.gameID = self.gameID
                vc.color = color
                vc.isHost = true
                self.present(vc, animated: true, completion: nil)
                self.setJoinedGame(color: color)
                self.shouldKill = true
            })
        }
    }
    
    func setupJoinObserver() {
        self.joinObserver = db?.collection("games").addSnapshotListener({ (snapshot, error) in
            if snapshot?.count == 0 {
                return
            }
            var IDList = [String]()
            for doc in snapshot!.documents {
                if (doc.data()["name"]) == nil {
                    continue
                }
                if doc.data()["open"] as! Bool == false {
                    continue
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
    
    @objc func hostRedTapped () {
        if hostNameField.text == "" {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }
        hostGame(color: "white")
    }
    
    @objc func hostBlackTapped () {
        if hostNameField.text == "" {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }
        hostGame(color: "black")
    }
    
    @objc func hostWaitingCancelTapped () {
        UIView.animate(withDuration: 1, animations: {
            self.hostWaitingScreen.alpha = 0
        }) { (val) in
            self.hostWaitingScreen.isHidden = true
        }
        self.hostObserver?.remove()
        db?.collection("games").document(gameID).delete()
        UIView.animate(withDuration: 0.7) {
            self.menuContainer.alpha = 1
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == hostNameField {
            menuVertPan.constant = -150
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveLinear], animations: {
                self.view.layoutIfNeeded()
            }) { (val) in
                
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
        else if textField == phoneEntryField {
            if let text = textField.text?.replacingOccurrences(of: " ", with: "") {
                if text.count != 10 || text.contains(where: {!$0.isNumber}) {
                    return false
                }
                else {
                    db?.collection("users").document(self.uid).setData(["phone" : text], merge: true)
                    db?.collection("tokens").document(text).setData(["token" : self.token], merge: true)
                    UIView.animate(withDuration: 0.7, animations: {
                        self.phoneEntryView.alpha = 0
                    }) { (val) in
                        self.phoneEntryView.isHidden = true
                        
                    }
                    textField.resignFirstResponder()
                    self.showContacts()
                    return true
                }
            }
            else {
                return false
            }
        }
        textField.resignFirstResponder()
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
        self.db?.collection("games").document(id).setData([
            "open" : false
            ], merge: true)
        self.db?.collection("games").document(id).getDocument(completion: { (snapshot, error) in
            self.joinObserver?.remove()
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "gameController") as! BoardViewController
            vc.gameID = id
            if snapshot?.data()?["hostColor"] == nil {
                self.joinTable.reloadData()
                return
            }
            else if snapshot?.data()?["hostColor"] as! String == "white" {
                vc.color = "black"
            }
            else {
                vc.color = "white"
            }
            self.gameID = id
            self.setJoinedGame(color: vc.color)
            vc.isHost = false
            self.present(vc, animated: true, completion: nil)
        })
    }
    
}

extension UITextField {
    func isEmpty () {
        print()
    }
}


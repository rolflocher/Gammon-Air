//
//  ChatView.swift
//  Gammon Air
//
//  Created by Rolf Locher on 6/1/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import UIKit
import Firebase

class ChatView: UIView, UITextFieldDelegate {

    @IBOutlet var contentView: UIView!
    @IBOutlet var sendButton: UIImageView!
    @IBOutlet var messageField: UILabel!
    @IBOutlet var messageButton: UIView!
    @IBOutlet var conversationScrollView: UIScrollView!
    @IBOutlet var ghostField: UITextField!
    @IBOutlet var messageButtonBottom: NSLayoutConstraint!
    
    var db : Firestore? = nil
    var listener : ListenerRegistration? = nil
    var messageList = [messageView]()
    let vertMessagePadding : CGFloat = 10
    var contentHeight : CGFloat = 0
    var connectionParams : cxParams? = nil {
        didSet {
            if connectionParams == nil {
                return
            }
            if listener == nil {
                subscribeToUpdates(fireParams: connectionParams!)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed("ChatView", owner: self, options: nil)
        contentView.fixInView(self)
        
        db = Firestore.firestore()
        
        messageField.text = ""
        
        ghostField.delegate = self
        ghostField.returnKeyType = .done
        
        let typeTap = UITapGestureRecognizer(target: self, action: #selector(typeTapped))
        messageButton.addGestureRecognizer(typeTap)
        messageButton.isUserInteractionEnabled = true
        
        let sendTap = UITapGestureRecognizer(target: self, action: #selector(sendTapped))
        sendButton.addGestureRecognizer(sendTap)
        sendButton.isUserInteractionEnabled = true
        
    }
    
    @objc func typeTapped () {
        ghostField.becomeFirstResponder()
        messageButtonBottom.constant = 370
        UIView.animate(withDuration: 0.3, animations: {
            self.layoutIfNeeded()
        }) { (val) in
            
        }
    }
    
    @objc func sendTapped () {
        if connectionParams == nil {
            return
        }
        db?.collection(connectionParams!.collection).document(connectionParams!.document).collection("messagesArchive").document().setData([
            "content": self.messageField.text ?? "issue 0",
            "time": Int(Date().timeIntervalSince1970),
            "sender": UIDevice.current.name,
            ])
        ghostField.text = ""
        messageField.text = ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        ghostField.resignFirstResponder()
        messageButtonBottom.constant = 34
        UIView.animate(withDuration: 0.3, animations: {
            self.layoutIfNeeded()
        }) { (val) in
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let format = messageField.text as NSString?
        messageField.text = format?.replacingCharacters(in: range, with: string)
        let textSize = messageField.text?.size(withAttributes: [NSAttributedString.Key.font:messageField.font!])
        if textSize?.width ?? 0 < messageField.frame.width {
            messageField.lineBreakMode = .byTruncatingTail
        }
        else {
            messageField.lineBreakMode = .byTruncatingHead
        }
        return true
    }
    
    func subscribeToUpdates(fireParams: cxParams) {
        listener = db?.collection(fireParams.collection).document(fireParams.document).collection("messagesArchive").order(by: "time", descending: true).limit(to: 1).addSnapshotListener({ (snapshot, error) in
            if error != nil {
                return
                
            }
            if snapshot!.documents.count == 0 {
                return
            }
            let docInfo = snapshot!.documents[0].data()
            let sender = docInfo["sender"] as! String
            
            let newMessageView = messageView(frame: CGRect(x: 20, y: 500, width: 20, height: 40))
            newMessageView.sender = sender
            newMessageView.content = docInfo["content"] as! String
            newMessageView.time = docInfo["time"] as! Int
            
            self.addMessageToBottom(view: newMessageView)
        })
    }
    
    func queryWindow(start: TimeInterval, limit: Int, fireParams: cxParams) {
        
    }
    
    func addMessageToBottom(view: messageView) {
        for mx in messageList {
            mx.frame = CGRect(x: mx.frame.minX, y: mx.frame.minY-messageList.last!.frame.height-2*vertMessagePadding, width: mx.frame.width, height: mx.frame.height)
        }
        contentHeight += view.height+2*vertMessagePadding
        if contentHeight > conversationScrollView.frame.height-340 {
            //conversationScrollView.contentMode = .center
            //conversationScrollView.contentSize.height = contentHeight
            //conversationScrollView.contentInset = UIEdgeInsets(top: contentHeight/2, left: 0, bottom: 0, right: 0)
        }
        self.messageList.append(view)
        self.conversationScrollView.addSubview(view)
    }

}

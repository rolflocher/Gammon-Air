//
//  messageView.swift
//  Gammon Air
//
//  Created by Rolf Locher on 6/1/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import UIKit

class messageView: UIView {

    @IBOutlet var contentView: UIView!
    @IBOutlet var messageLabel: UILabel!
    
    var content = String() {
        didSet {
            messageLabel.text = content
            scaleForText()
        }
    }
    var sender = String()
    var time = Int()
    var height = CGFloat()
    let deviceWidth = UIScreen.main.bounds.width
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed("MessageView", owner: self, options: nil)
        contentView.fixInView(self)
        contentView.clipRound(10)
    }
    
    func scaleForText() {
        let textSize = messageLabel.text?.size(withAttributes: [NSAttributedString.Key.font:messageLabel.font!])
        var newWidth = CGFloat()
        if textSize?.width ?? 0 < 250 {
            newWidth = (textSize?.width ?? 0)+30
        }
        else {
            newWidth = 250
            messageLabel.numberOfLines = Int(ceil(Double((textSize?.width ?? 0)/250)))
        }
        let frame = contentView.frame
        if sender == UIDevice.current.name {
            self.frame = CGRect(x: deviceWidth-20-newWidth, y: frame.minY, width: newWidth, height: CGFloat(messageLabel.numberOfLines)*25+20)
        }
        else {
            self.frame = CGRect(x: frame.minX, y: frame.minY, width: newWidth, height: CGFloat(messageLabel.numberOfLines)*25+20)
        }
        
        height = CGFloat(messageLabel.numberOfLines)*25+20
    }

}

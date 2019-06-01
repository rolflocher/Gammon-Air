//
//  NotificationView.swift
//  Gammon Air
//
//  Created by Rolf Locher on 5/27/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import UIKit

class NotificationView: UIView {

    @IBOutlet var contentView: UIView!
    @IBOutlet var acceptButton: UIImageView!
    @IBOutlet var declineButton: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    
    var gameID = String()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed("NotificationView", owner: self, options: nil)
        contentView.fixInView(self)
        
        acceptButton.clipRound(8.0)
        declineButton.clipRound(8.0)
    }

}

//
//  Extensions.swift
//  Gammon Air
//
//  Created by Rolf Locher on 5/28/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import Foundation
import UIKit

struct cxParams {
    var collection = String()
    var document = String()
}

extension NSLayoutConstraint {
    func animateConstantTo(_ constant: CGFloat, withDuration dur: TimeInterval, layoutUpdate: @escaping()->Void, completion: @escaping()->Void) {
        self.constant = constant
        UIView.animate(withDuration: dur, animations: {
            layoutUpdate()
        }) { (val) in
            completion()
        }
    }
    func animateConstantForeverBetween(_ start: CGFloat, _ end: CGFloat, withDuration dur: TimeInterval, layoutUpdate: @escaping()->Void) {
        self.animateConstantTo(start, withDuration: dur, layoutUpdate: layoutUpdate) {
            self.animateConstantForeverBetween(end, start, withDuration: dur, layoutUpdate: layoutUpdate)
        }
    }
}

extension UIImageView {
    func glimmer(dir: Bool) {
        if dir {
            UIView.animate(withDuration: 1.4, animations: {
                self.alpha = 0.75
            }) { (val) in
                self.glimmer(dir: false)
            }
        }
        else {
            UIView.animate(withDuration: 1.4, animations: {
                self.alpha = 0
            }) { (val) in
                self.glimmer(dir: true)
            }
        }
    }
    
}

extension UILabel {
    func glimmer(dir: Bool) {
        if dir {
            UIView.animate(withDuration: 1.4, animations: {
                self.alpha = 0.75
            }) { (val) in
                self.glimmer(dir: false)
            }
        }
        else {
            UIView.animate(withDuration: 1.4, animations: {
                self.alpha = 0
            }) { (val) in
                self.glimmer(dir: true)
            }
        }
    }
}

extension UIView
{
    func clipRound(_ radius : CGFloat) {
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
    
    func fixInView(_ container: UIView!){
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.frame = container.frame;
        container.addSubview(self);
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}

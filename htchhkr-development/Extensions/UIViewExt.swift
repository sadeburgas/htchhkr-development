//
//  UIViewExt.swift
//  htchhkr-development
//
//  Created by sade on 15/9/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit

extension UIView {
    func fadeTo(alphaValue: CGFloat, withDuration duration: TimeInterval) {
        UIView.animate(withDuration: duration) {
            self.alpha = alphaValue
        }
    }
}

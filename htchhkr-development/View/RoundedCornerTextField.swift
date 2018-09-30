//
//  RoundedCornerTextField.swift
//  htchhkr-development
//
//  Created by sade on 16/9/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit

class RoundedCornerTextField: UITextField {
    
    var textRectOffset: CGFloat = 20
    
    override func awakeFromNib() {
        setupView()
    }
    
    func setupView() {
        self.layer.cornerRadius = self.frame.height / 2
        self.clipsToBounds = true
    }
    
//    override func textRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 , width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
//    }
    
//    override func editingRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
//    }
    
//    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height)
//    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        
        return bounds.inset(by: UIEdgeInsets.init(top: 0, left: textRectOffset, bottom: 0, right: textRectOffset))
        
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        
        return bounds.inset(by: UIEdgeInsets.init(top: 0, left: textRectOffset, bottom: 0, right: textRectOffset))
        
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        
        return bounds.inset(by: UIEdgeInsets.init(top: 0, left: textRectOffset, bottom: 0, right: textRectOffset))
        
    }
    
}

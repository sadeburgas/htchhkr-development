//
//  RoundImageView.swift
//  htchhkr-development
//
//  Created by sade on 8/9/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit

class RoundImageView: UIImageView {
    
    override func awakeFromNib() {
        setupView()
    }

    func setupView (){
        self.layer.cornerRadius = self.frame.width / 2
        self.clipsToBounds = true
    }

}

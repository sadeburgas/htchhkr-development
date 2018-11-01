//
//  RoundMapView.swift
//  htchhkr-development
//
//  Created by sade on 31/10/2018.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit
import MapKit

class RoundMapView: MKMapView {

    override func awakeFromNib() {
        setupView()
    }
    func setupView() {
        self.layer.cornerRadius = self.frame.width / 2
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.borderWidth = 10.0
    }
    
}

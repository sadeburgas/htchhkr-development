//
//  ViewController.swift
//  htchhkr-development
//
//  Created by sade on 27/8/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController , MKMapViewDelegate{

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {
        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
    }
    
}


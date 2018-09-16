//
//  LoginVC.swift
//  htchhkr-development
//
//  Created by sade on 15/9/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit

class LoginVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bindtoKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }

    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }

    @IBAction func canselBtnWasPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

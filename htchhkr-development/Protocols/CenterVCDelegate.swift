//
//  CenterVCDelegate.swift
//  htchhkr-development
//
//  Created by sade on 9/9/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit

protocol CenterVCDelegate {
    func toggleLeftPanel()
    func addLeftPanelViewController()
    func animateLeftPanel(shouldExpand: Bool)
}

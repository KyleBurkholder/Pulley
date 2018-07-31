//
//  DoublePulleyViewController.swift
//  Pulley
//
//  Created by Kyle Burkholder on 7/30/18.
//  Copyright © 2018 52inc. All rights reserved.
//

import UIKit

open class DoublePulleyViewController: PulleyViewController
{
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var topDrawerContentContainerView: UIView!
    
    // Internal
    let topDrawerContentContainer: UIView = UIView()
    let topDrawerShadowView: UIView = UIView()
    let topDrawerScrollView: PulleyPassthroughScrollView = PulleyPassthroughScrollView()

    
    /// The current top drawer view controller (shown in the top drawer).
    public internal(set) var topDrawerContentViewController: UIViewController! {
        willSet {
            
            guard let controller = topDrawerContentViewController else {
                return
            }
            
            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = topDrawerContentViewController else {
                return
            }
            
            addChildViewController(controller)
            
            topDrawerContentContainer.addSubview(controller.view)
            
            controller.view.constrainToParent()
            
            controller.didMove(toParentViewController: self)
            
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
}

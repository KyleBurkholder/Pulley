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
    
    // Public
    public var topDrawer: PulleyDrawer = PulleyDrawer(originSide: .top)

    /// The current drawer view controller (shown in the drawer).
    public internal(set) var topDrawerContentViewController: UIViewController! {
        willSet {
            
            guard let controller = drawerContentViewController else {
                return
            }
            
            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = drawerContentViewController else {
                return
            }
            
            addChildViewController(controller)
            
            topDrawer.contentContainer.addSubview(controller.view)
            topDrawer.drawerDelegate = (controller as? PulleyDrawerViewControllerDelegate)
            
            controller.view.constrainToParent()
            
            controller.didMove(toParentViewController: self)
            
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
    
    /// Get the current bottom safe area for Pulley. This is a convenience accessor. Most delegate methods where you'd need it will deliver it as a parameter.
    public var topSafeSpace: CGFloat {
        get {
            return pulleySafeAreaInsets.top
        }
    }
    
    /**
     Initialize the drawer controller programmtically.
     
     - parameter contentViewController: The content view controller. This view controller is shown behind the drawer.
     - parameter bottomDrawerViewController:  The view controller to display inside the bottom drawer.
     - parameter topDrawerViewController:  The view controller to display inside the top drawer.

     
     - note: The drawer VCs are 20pts too tall in order to have some extra space for the bounce animation. Make sure your constraints / content layout take this into account.
     
     - returns: A newly created Pulley drawer.
     */
    public required init(contentViewController: UIViewController, bottomDrawerViewController: UIViewController, topDrawerViewController: UIViewController)
    {
        super.init(contentViewController: contentViewController, drawerViewController: bottomDrawerViewController)
        ({self.topDrawerContentViewController = topDrawerViewController})()
    }
    
    /**
     Initialize the drawer controller from Interface Builder.
     
     - note: Usage notes: Make 3 container views in Interface Builder and connect their outlets to -primaryContentContainerView, -drawerContentContainerView, and -topDrawerContentContainerView. Then use embed segues to place your content/drawer view controllers into the appropriate container.
     
     - parameter aDecoder: The NSCoder to decode from.
     
     - returns: A newly created Pulley drawer.
     */
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override open func loadView()
    {
        super.loadView()
        
        // IB Support
        if topDrawerContentContainerView != nil
        {
            topDrawerContentContainerView.removeFromSuperview()
        }
        
        topDrawer.scrollView.delegate = self
        topDrawer.scrollView.touchDelegate = self
        topDrawer.delegate = self
        
        self.view.addSubview(topDrawer.scrollView)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // IB Support
        if topDrawerContentViewController == nil
        {
            assert(topDrawerContentContainerView != nil, "When instantiating from Interface Builder you must provide container views with an embedded view controller.")
            
            // Locate main content VC
            for child in self.childViewControllers
            {
                if child.view == topDrawerContentContainerView.subviews.first
                {
                    topDrawerContentViewController = child
                }
            }
            
            assert(topDrawerContentViewController != nil, "Container views must contain an embedded view controller.")
        }
        
        topDrawer.enforceCanScrollDrawer()
        setDrawerPosition(for: topDrawer, position: topDrawer.initialDrawerPosition, animated: false)
        scrollViewDidScroll(topDrawer.scrollView)
        
        delegate?.drawerDisplayModeDidChange?(drawer: self, ofType: .top)
        (topDrawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: .top)
        (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: .top)
    }
    
    override open func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        // Make sure our view controller views are subviews of the right view (Resolves #21 issue with changing the presentation context)
        
        // May be nil during initial layout
        if let primary = primaryContentViewController
        {
            if primary.view.superview != nil && primary.view.superview != primaryContentContainer
            {
                primaryContentContainer.addSubview(primary.view)
                primaryContentContainer.sendSubview(toBack: primary.view)
                
                primary.view.constrainToParent()
            }
        }
        
        // May be nil during initial layout
        if let drawer = drawerContentViewController
        {
            if drawer.view.superview != nil && drawer.view.superview != bottomDrawer.contentContainer
            {
                bottomDrawer.contentContainer.addSubview(drawer.view)
                bottomDrawer.contentContainer.sendSubview(toBack: drawer.view)
                
                drawer.view.constrainToParent()
            }
        }
        
        // May be nil during initial layout
        if let drawer = topDrawerContentViewController
        {
            if drawer.view.superview != nil && drawer.view.superview != topDrawer.contentContainer
            {
                topDrawer.contentContainer.addSubview(drawer.view)
                topDrawer.contentContainer.sendSubview(toBack: drawer.view)
                
                drawer.view.constrainToParent()
            }
        }
        
        // Currently only .drawer is supported for a DoublePulleyViewController. I might add this later?
        //TODO: Maybe add leftSide capability for either one or both drawers.
//        let displayModeForCurrentLayout: PulleyDisplayMode = bottomDrawer.displayMode != .automatic ? bottomDrawer.displayMode : ((self.view.bounds.width >= 600.0 || self.traitCollection.horizontalSizeClass == .regular) ? .leftSide : .drawer)
        
        bottomDrawer.currentDisplayMode = .drawer
        topDrawer.currentDisplayMode = .drawer
        
        didLayoutSubviews(for: bottomDrawer)
        didLayoutSubviews(for: topDrawer)
        
        
        //TODO: Make maskBackroundDimmingView work with two Drawers
//        backgroundDimmingView.frame = CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: self.view.bounds.height + drawer.scrollView.contentSize.height)
//        // I don't think that I need this? on height. Or I do.
//        print("backgroundDimmingView frame = \(backgroundDimmingView.frame)")
//        
//        backgroundDimmingView.isHidden = false
//        
//
//        maskBackgroundDimmingView()
    }
    
    /**
     Update the supported drawer positions allows by the Pulley Drawer
     */
    //TODO: Test this Functionality
    override public func setNeedsSupportedDrawerPositionsUpdate()
    {
        for child in self.childViewControllers
        {
            if let drawerVCCompliant = child as? PulleyDrawerViewControllerDelegate{
                switch child
                {
                case drawerContentViewController:
                    bottomDrawer.supportedPositions = drawerVCCompliant.supportedDrawerPositions?() ?? PulleyPosition.all
                case topDrawerContentViewController:
                    topDrawer.supportedPositions = drawerVCCompliant.supportedDrawerPositions?() ?? PulleyPosition.all
                default:
                    continue
                }
            }
        }
    }
    
    //MARK: Private functions
    
    private func didLayoutSubviews(for drawer: PulleyDrawer)
    {
        let originSafeArea = getOriginSafeArea(for: drawer)
        
        // Bottom inset for safe area / bottomLayoutGuide
        if #available(iOS 11, *) {
            switch drawer.type
            {
            case .bottom:
            drawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            case .top:
            drawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            default:
                return
            }

        } else {
            self.automaticallyAdjustsScrollViewInsets = false
            switch drawer.type
            {
            case .bottom:
                drawer.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: originSafeArea, right: 0)
                drawer.scrollView.scrollIndicatorInsets =  UIEdgeInsets(top: 0, left: 0, bottom: originSafeArea, right: 0) // (usefull if visible..)
            case .top:
                drawer.scrollView.contentInset = UIEdgeInsets(top: originSafeArea, left: 0, bottom: 0, right: 0)
                drawer.scrollView.scrollIndicatorInsets =  UIEdgeInsets(top: originSafeArea, left: 0, bottom: 0, right: 0) // (usefull if visible..)
            default:
                return
            }
        }

        let mostCollapsedHeight = getStopList(for: drawer).min() ?? 0
        print(mostCollapsedHeight)
        
        let adjustedLeftSafeArea = bottomDrawer.adjustDrawerHorizontalInsetToSafeArea ? pulleySafeAreaInsets.left : 0.0
        let adjustedRightSafeArea = bottomDrawer.adjustDrawerHorizontalInsetToSafeArea ? pulleySafeAreaInsets.right : 0.0
        
        // Layout scrollview
        let drawerheight: CGFloat = getStopList(for: drawer).max() ?? 0.0
        let yOrigin: CGFloat
        switch drawer.type
        {
        case .bottom:
            yOrigin = self.view.bounds.height - drawerheight
            
        case .top:
            yOrigin = 0.0
        default:
            return
        }
        
        drawer.scrollView.frame = CGRect(x: adjustedLeftSafeArea, y: yOrigin, width: self.view.bounds.width - adjustedLeftSafeArea - adjustedRightSafeArea, height: drawerheight)
        
        print("\(drawer.type.rawValue) drawerScrollView frame = \(drawer.scrollView.frame)")
        
        drawer.scrollView.addSubview(drawer.shadowView)
        if let drawerBackgroundVisualEffectView = drawer.backgroundVisualEffectView
        {
            drawer.scrollView.addSubview(drawerBackgroundVisualEffectView)
            drawerBackgroundVisualEffectView.layer.cornerRadius = drawer.cornerRadius
        }
        drawer.scrollView.addSubview(drawer.contentContainer)
        
        let yContentContainer: CGFloat
        let heightContentContainer: CGFloat = drawer.scrollView.bounds.height + drawer.bounceOverflowMargin
        let cornerToRound: UIRectCorner
        var contentSize: CGFloat = drawer.scrollView.bounds.height * 2.0 - mostCollapsedHeight + (drawer.bounceOverflowMargin - 5.0)
        switch drawer.type
        {
        case .bottom:
            yContentContainer = drawer.scrollView.bounds.height - mostCollapsedHeight
            cornerToRound =  [.topLeft, .topRight]
            contentSize -= originSafeArea
        case .top:
            yContentContainer = -(drawer.bounceOverflowMargin) + (drawer.bounceOverflowMargin - 5.0) - originSafeArea
            cornerToRound = [.bottomLeft, .bottomRight]
            contentSize -= 0.0
        default:
            return
        }
        drawer.contentContainer.frame = CGRect(x: 0, y: yContentContainer, width: drawer.scrollView.bounds.width, height: heightContentContainer)
        print("\(drawer.type.rawValue) drawerContentContainer frame = \(drawer.contentContainer.frame)")
        drawer.backgroundVisualEffectView?.frame = drawer.contentContainer.frame
        drawer.shadowView.frame = drawer.contentContainer.frame
//        drawer.scrollView.contentSize = CGSize(width: drawer.scrollView.bounds.width, height: (drawer.scrollView.bounds.height - mostCollapsedHeight) + drawer.scrollView.bounds.height - originSafeArea + (drawer.bounceOverflowMargin - 5.0))
        drawer.scrollView.contentSize = CGSize(width: drawer.scrollView.bounds.width, height: contentSize)
        
        print("drawer.scrollView.contentoffest = \(drawer.scrollView.contentOffset.y)")
        print("\(drawer.type.rawValue) drawerScrollView contentSize = \(drawer.scrollView.contentSize)")
        
        // Update rounding mask and shadows
        let borderPath = UIBezierPath(roundedRect: drawer.contentContainer.bounds, byRoundingCorners: cornerToRound, cornerRadii: CGSize(width: drawer.cornerRadius, height: drawer.cornerRadius)).cgPath
        
        let cardMaskLayer = CAShapeLayer()
        cardMaskLayer.path = borderPath
        cardMaskLayer.frame = drawer.contentContainer.bounds
        cardMaskLayer.fillColor = UIColor.white.cgColor
        cardMaskLayer.backgroundColor = UIColor.clear.cgColor
        drawer.contentContainer.layer.mask = cardMaskLayer
        drawer.shadowView.layer.shadowPath = borderPath
        
        drawer.scrollView.transform = CGAffineTransform.identity
        drawer.contentContainer.transform = drawer.scrollView.transform
        drawer.shadowView.transform = drawer.scrollView.transform
//        setDrawerPosition(for: drawer, position: drawer.drawerPosition, animated: false)
    }
}

//
//  PulleyViewController.swift
//  Pulley
//
//  Created by Brendan Lee on 7/6/16.
//  Copyright © 2016 52inc. All rights reserved.
//

import UIKit

/**
 *  The base delegate protocol for Pulley delegates.
 */
@objc public protocol PulleyDelegate: class {
    
    /** This is called after size changes, so if you care about the bottomSafeArea property for custom UI layout, you can use this value.
     * NOTE: It's not called *during* the transition between sizes (such as in an animation coordinator), but rather after the resize is complete.
     */
    @objc optional func drawerPositionDidChange(drawer: PulleyViewController, bottomSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for when Pulley goes to 'fullscreen'. Bottom safe area is provided for your convenience.
     */
    @objc optional func makeUIAdjustmentsForFullscreen(progress: CGFloat, bottomSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for changes in the drawer's distance-to-bottom. Bottom safe area is provided for your convenience.
     */
    @objc optional func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat)
    
    /**
     *  Called when the current drawer display mode changes (leftSide vs bottomDrawer). Make UI changes to account for this here.
     */
    @objc optional func drawerDisplayModeDidChange(drawer: PulleyViewController, ofType drawerType: DrawerType)
}

/**
 *  View controllers in the drawer can implement this to receive changes in state or provide values for the different drawer positions.
 */
@objc public protocol PulleyDrawerViewControllerDelegate: PulleyDelegate {
    
    /**
     *  Provide the collapsed drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: origin safe area is provided for your convenience in computing a value to return.
     */
    @objc optional func collapsedDrawerHeight(originSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Provide the standard drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: origin safe area is provided for your convenience in computing a value to return.
     */
    @objc optional func standardDrawerHeight(originSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Provide the partialReveal drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: origin safe area is provided for your convenience in computing a value to return.
     */
    @objc optional func partialRevealDrawerHeight(originSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Provide the reveal drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: origin safe area is provided for your convenience in computing a value to return.
     */
    @objc optional func revealDrawerHeight(originSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Return the support drawer positions for your drawer.
     */
    @objc optional func supportedDrawerPositions() -> [PulleyPosition]
}

/**
 *  View controllers that are the main content can implement this to receive changes in state.
 */
@objc public protocol PulleyPrimaryContentControllerDelegate: PulleyDelegate {
    
    // Not currently used for anything, but it's here for parity with the hopes that it'll one day be used.
}

/**
 *  A completion block used for animation callbacks.
 */
public typealias PulleyAnimationCompletionBlock = ((_ finished: Bool) -> Void)


let kPulleyDefaultCollapsedHeight: CGFloat = 68.0
let kPulleyDefaultStandardHeight: CGFloat = 170.0
let kPulleyDefaultPartialRevealHeight: CGFloat = 264.0
let kPulleyDefaultRevealHeight: CGFloat = 380.0

open class PulleyViewController: UIViewController, PulleyDrawerViewControllerDelegate {
    
    // Interface Builder
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var primaryContentContainerView: UIView!
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var drawerContentContainerView: UIView!
    
    // Internal
    let primaryContentContainer: UIView = UIView()
    let backgroundDimmingView: UIView = UIView()
    var dimmingViewTapRecognizer: UITapGestureRecognizer?
    var lastDragTargetContentOffset: CGPoint = CGPoint.zero

    // Public
    
    public var bottomDrawer: PulleyDrawer = PulleyDrawer(originSide: .bottom)

    //public let bottomDrawer.bounceOverflowMargin: CGFloat = 20.0

    /// The current content view controller (shown behind the drawer).
    public internal(set) var primaryContentViewController: UIViewController! {
        willSet {
            
            guard let controller = primaryContentViewController else {
                return
            }

            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = primaryContentViewController else {
                return
            }

            addChildViewController(controller)

            primaryContentContainer.addSubview(controller.view)
            
            controller.view.constrainToParent()
            
            controller.didMove(toParentViewController: self)

            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
    
    /// The current drawer view controller (shown in the drawer).
    public internal(set) var drawerContentViewController: UIViewController! {
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

            bottomDrawer.contentContainer.addSubview(controller.view)
            bottomDrawer.drawerDelegate = (controller as? PulleyDrawerViewControllerDelegate)
            
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
    public var bottomSafeSpace: CGFloat {
        get {
            return pulleySafeAreaInsets.bottom
        }
    }
    
    /// The content view controller and drawer controller can receive delegate events already. This lets another object observe the changes, if needed.
    public weak var delegate: PulleyDelegate?
    
    /// The opaque color of the background dimming view.
    public var backgroundDimmingColor: UIColor = UIColor.black {
        didSet {
            if self.isViewLoaded
            {
                backgroundDimmingView.backgroundColor = backgroundDimmingColor
            }
        }
    }
    
    /// The maximum amount of opacity when dimming.
    public var backgroundDimmingOpacity: CGFloat = 0.5 {
        didSet {
            
            if self.isViewLoaded
            {
                self.scrollViewDidScroll(bottomDrawer.scrollView)
            }
        }
    }
    
    /// Access to the safe areas that Pulley is using for layout (provides compatibility for iOS < 11)
    public var pulleySafeAreaInsets: UIEdgeInsets {
        
        var safeAreaBottomInset: CGFloat = 0
        var safeAreaLeftInset: CGFloat = 0
        var safeAreaRightInset: CGFloat = 0
        var safeAreaTopInset: CGFloat = 0
        
        if #available(iOS 11.0, *)
        {
            safeAreaBottomInset = view.safeAreaInsets.bottom
            safeAreaLeftInset = view.safeAreaInsets.left
            safeAreaRightInset = view.safeAreaInsets.right
            safeAreaTopInset = view.safeAreaInsets.top
        }
        else
        {
            safeAreaBottomInset = self.bottomLayoutGuide.length
            safeAreaTopInset = self.topLayoutGuide.length
        }
        
        return UIEdgeInsets(top: safeAreaTopInset, left: safeAreaLeftInset, bottom: safeAreaBottomInset, right: safeAreaRightInset)
    }
        
    
    
    /**
     Initialize the drawer controller programmtically.
     
     - parameter contentViewController: The content view controller. This view controller is shown behind the drawer.
     - parameter drawerViewController:  The view controller to display inside the drawer.
     
     - note: The drawer VC is 20pts too tall in order to have some extra space for the bounce animation. Make sure your constraints / content layout take this into account.
     
     - returns: A newly created Pulley drawer.
     */
    public init(contentViewController: UIViewController, drawerViewController: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        
        ({
            self.primaryContentViewController = contentViewController
            self.drawerContentViewController = drawerViewController
        })()
    }
    
    /**
     Initialize the drawer controller from Interface Builder.
     
     - note: Usage notes: Make 2 container views in Interface Builder and connect their outlets to -primaryContentContainerView and -drawerContentContainerView. Then use embed segues to place your content/drawer view controllers into the appropriate container.
     
     - parameter aDecoder: The NSCoder to decode from.
     
     - returns: A newly created Pulley drawer.
     */
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func loadView() {
        super.loadView()
        
        // IB Support
        if primaryContentContainerView != nil
        {
            primaryContentContainerView.removeFromSuperview()
        }
        
        if drawerContentContainerView != nil
        {
            drawerContentContainerView.removeFromSuperview()
        }
        
        // Setup
        primaryContentContainer.backgroundColor = UIColor.white
        
        definesPresentationContext = true
        
        bottomDrawer.scrollView.delegate = self
        bottomDrawer.scrollView.touchDelegate = self
        bottomDrawer.delegate = self
        
//        bottomDrawer.scrollView.bounces = false
//        bottomDrawer.scrollView.clipsToBounds = false
//        bottomDrawer.scrollView.showsVerticalScrollIndicator = false
//        bottomDrawer.scrollView.showsHorizontalScrollIndicator = false
//
//        bottomDrawer.scrollView.delaysContentTouches = bottomDrawer.delaysContentTouches
//        bottomDrawer.scrollView.canCancelContentTouches = bottomDrawer.canCancelContentTouches
//
//        //drawerScrollView.backgroundColor = UIColor.clear
//        bottomDrawer.scrollView.backgroundColor = UIColor.green
//        bottomDrawer.scrollView.decelerationRate = UIScrollViewDecelerationRateFast
//        bottomDrawer.scrollView.scrollsToTop = false
//
//
//        bottomDrawer.shadowView.layer.shadowOpacity = bottomDrawer.shadowOpacity
//        bottomDrawer.shadowView.layer.shadowRadius = bottomDrawer.shadowRadius
//        bottomDrawer.shadowView.backgroundColor = UIColor.clear
        
//        bottomDrawer.contentContainer.backgroundColor = UIColor.clear
        
        
        
        backgroundDimmingView.backgroundColor = backgroundDimmingColor
        backgroundDimmingView.isUserInteractionEnabled = false
        backgroundDimmingView.alpha = 0.0
        
//        bottomDrawer.backgroundVisualEffectView?.clipsToBounds = true
        
        dimmingViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PulleyViewController.dimmingViewTapRecognizerAction(gestureRecognizer:)))
        backgroundDimmingView.addGestureRecognizer(dimmingViewTapRecognizer!)
        
        //bottomDrawer.scrollView.addSubview(bottomDrawer.shadowView)
        
//        if let drawerBackgroundVisualEffectView = bottomDrawer.backgroundVisualEffectView
//        {
//            bottomDrawer.scrollView.addSubview(drawerBackgroundVisualEffectView)
//            drawerBackgroundVisualEffectView.layer.cornerRadius = bottomDrawer.cornerRadius
//        }
        
//        bottomDrawer.scrollView.addSubview(bottomDrawer.contentContainer)
        
        primaryContentContainer.backgroundColor = UIColor.white
        
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(primaryContentContainer)
        self.view.addSubview(backgroundDimmingView)
        self.view.addSubview(bottomDrawer.scrollView)
        
        primaryContentContainer.constrainToParent()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // IB Support
        if primaryContentViewController == nil || drawerContentViewController == nil
        {
            assert(primaryContentContainerView != nil && drawerContentContainerView != nil, "When instantiating from Interface Builder you must provide container views with an embedded view controller.")
            
            // Locate main content VC
            for child in self.childViewControllers
            {
                if child.view == primaryContentContainerView.subviews.first
                {
                    primaryContentViewController = child
                }
                
                if child.view == drawerContentContainerView.subviews.first
                {
                    drawerContentViewController = child
                }
            }
            
            assert(primaryContentViewController != nil && drawerContentViewController != nil, "Container views must contain an embedded view controller.")
        }

        bottomDrawer.enforceCanScrollDrawer()
        setDrawerPosition(for: bottomDrawer, position: bottomDrawer.initialDrawerPosition, animated: false)
        scrollViewDidScroll(bottomDrawer.scrollView)
        
        delegate?.drawerDisplayModeDidChange?(drawer: self, ofType: .bottom)
        (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: .bottom)
        (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: .bottom)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setNeedsSupportedDrawerPositionsUpdate()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("viewDidLayoutSubviews")
        
        //TODO: Find out how to check what self's type is. Hacky way installed.
        guard (self as? DoublePulleyViewController) == nil else { return }
        
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
        
        let displayModeForCurrentLayout: PulleyDisplayMode = bottomDrawer.displayMode != .automatic ? bottomDrawer.displayMode : ((self.view.bounds.width >= 600.0 || self.traitCollection.horizontalSizeClass == .regular) ? .leftSide : .drawer)
        
        bottomDrawer.currentDisplayMode = displayModeForCurrentLayout
        
        if displayModeForCurrentLayout == .drawer
        {
            print("bottomLayoutGuide.length \(self.bottomLayoutGuide.length)")
            print("topLayoutGuide.length \(self.topLayoutGuide.length)")
            // Bottom inset for safe area / bottomLayoutGuide
            if #available(iOS 11, *) {
                self.bottomDrawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            } else {
                self.automaticallyAdjustsScrollViewInsets = false
                self.bottomDrawer.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.bottomLayoutGuide.length, right: 0)
                self.bottomDrawer.scrollView.scrollIndicatorInsets =  UIEdgeInsets(top: 0, left: 0, bottom: self.bottomLayoutGuide.length, right: 0) // (usefull if visible..)
            }

            let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
            
            let adjustedLeftSafeArea = bottomDrawer.adjustDrawerHorizontalInsetToSafeArea ? pulleySafeAreaInsets.left : 0.0
            let adjustedRightSafeArea = bottomDrawer.adjustDrawerHorizontalInsetToSafeArea ? pulleySafeAreaInsets.right : 0.0
            
                // Layout scrollview
            let adjustedTopInset: CGFloat = getStopList(for: bottomDrawer).max() ?? 0.0
            bottomDrawer.scrollView.frame = CGRect(x: adjustedLeftSafeArea, y: self.view.bounds.height - adjustedTopInset, width: self.view.bounds.width - adjustedLeftSafeArea - adjustedRightSafeArea, height: adjustedTopInset)
            
            print("drawerScrollView frame = \(bottomDrawer.scrollView.frame)")
            print("Number of scrollView subViews(start): \(bottomDrawer.scrollView.subviews.count)")
            bottomDrawer.scrollView.addSubview(bottomDrawer.shadowView)
            print("Number of scrollView subViews(start): \(bottomDrawer.scrollView.subviews.count)")
            if let drawerBackgroundVisualEffectView = bottomDrawer.backgroundVisualEffectView
            {
                bottomDrawer.scrollView.addSubview(drawerBackgroundVisualEffectView)
                drawerBackgroundVisualEffectView.layer.cornerRadius = bottomDrawer.cornerRadius
            }
            print("Number of scrollView subViews(start): \(bottomDrawer.scrollView.subviews.count)")
            bottomDrawer.scrollView.addSubview(bottomDrawer.contentContainer)
            print("Number of scrollView subViews(start): \(bottomDrawer.scrollView.subviews.count)")
            
            bottomDrawer.contentContainer.frame = CGRect(x: 0, y: bottomDrawer.scrollView.bounds.height - lowestStop, width: bottomDrawer.scrollView.bounds.width, height: bottomDrawer.scrollView.bounds.height + bottomDrawer.bounceOverflowMargin)
            print("drawerContentContainer frame = \(bottomDrawer.contentContainer.frame)")
            bottomDrawer.backgroundVisualEffectView?.frame = bottomDrawer.contentContainer.frame
            bottomDrawer.shadowView.frame = bottomDrawer.contentContainer.frame
            bottomDrawer.scrollView.contentSize = CGSize(width: bottomDrawer.scrollView.bounds.width, height: (bottomDrawer.scrollView.bounds.height - lowestStop) + bottomDrawer.scrollView.bounds.height - pulleySafeAreaInsets.bottom + (bottomDrawer.bounceOverflowMargin - 5.0))
            print("drawerScrollView contentSize = \(bottomDrawer.scrollView.contentSize)")
            
            // Update rounding mask and shadows
            let borderPath = UIBezierPath(roundedRect: bottomDrawer.contentContainer.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius)).cgPath
            
            let cardMaskLayer = CAShapeLayer()
            cardMaskLayer.path = borderPath
            cardMaskLayer.frame = bottomDrawer.contentContainer.bounds
            cardMaskLayer.fillColor = UIColor.white.cgColor
            cardMaskLayer.backgroundColor = UIColor.clear.cgColor
            bottomDrawer.contentContainer.layer.mask = cardMaskLayer
            bottomDrawer.shadowView.layer.shadowPath = borderPath
            
            backgroundDimmingView.frame = CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: self.view.bounds.height + bottomDrawer.scrollView.contentSize.height)
            // I don't think that I need this? on height. Or I do.
            print("backgroundDimmingView frame = \(backgroundDimmingView.frame)")
            
            bottomDrawer.scrollView.transform = CGAffineTransform.identity
            
            backgroundDimmingView.isHidden = false
        }
        else
        {
            // Bottom inset for safe area / bottomLayoutGuide
            if #available(iOS 11, *) {
                self.bottomDrawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            } else {
                self.automaticallyAdjustsScrollViewInsets = false
                self.bottomDrawer.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0.0, right: 0)
                self.bottomDrawer.scrollView.scrollIndicatorInsets =  UIEdgeInsets(top: 0, left: 0, bottom: 0.0, right: 0)
            }
            
            // Layout container
            
            //let lowestStop = [(self.view.bounds.size.height - topInset - pulleySafeAreaInsets.top), collapsedHeight, revealHeight, partialRevealHeight].min() ?? 0
            //Why not try this?
            let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
            
            if bottomDrawer.supportedPositions.contains(.open)
            {
                // Layout scrollview
                bottomDrawer.scrollView.frame = CGRect(x: pulleySafeAreaInsets.left + bottomDrawer.panelInsetLeft, y: bottomDrawer.panelInsetTop + pulleySafeAreaInsets.top, width: bottomDrawer.panelWidth, height: bottomDrawer.heightOfOpenDrawer)
            }
            else
            {
                // Layout scrollview
                let adjustedTopInset: CGFloat = bottomDrawer.supportedPositions.contains(.partiallyRevealed) ? bottomDrawer.partialRevealHeight : bottomDrawer.collapsedHeight
                bottomDrawer.scrollView.frame = CGRect(x: pulleySafeAreaInsets.left + bottomDrawer.panelInsetLeft, y: bottomDrawer.panelInsetTop + pulleySafeAreaInsets.top, width: bottomDrawer.panelWidth, height: adjustedTopInset)
            }

            syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
            
            bottomDrawer.scrollView.contentSize = CGSize(width: bottomDrawer.scrollView.bounds.width, height: self.view.bounds.height + (self.view.bounds.height - lowestStop))
            
            bottomDrawer.scrollView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            backgroundDimmingView.isHidden = true
        }
        
        bottomDrawer.contentContainer.transform = bottomDrawer.scrollView.transform
        bottomDrawer.shadowView.transform = bottomDrawer.scrollView.transform
        
        maskBackgroundDimmingView()
        setDrawerPosition(for: bottomDrawer, position: bottomDrawer.drawerPosition, animated: false)
    }

    // MARK: Internal State Updates

    func getStopList(for drawer: PulleyDrawer) -> [CGFloat] {
    
        let drawerStops = drawer.supportedPositions.map({stopValue(for: $0, from: drawer)})
        
        return drawerStops
    }
    
    func stopValue(for position: PulleyPosition, from drawer: PulleyDrawer) -> CGFloat
    {
        switch position {
            
        case .collapsed:
            return drawer.collapsedHeight
            
        case .standard:
            return drawer.standardlHeight
            
        case .partiallyRevealed:
            return drawer.partialRevealHeight
            
        case .revealed:
            return drawer.revealHeight
            
        case .open:
            return drawer.heightOfOpenDrawer
            
        case .closed:
            return 0
            
        default:
            return 0
        }
    }
    
    func drawerPosition(for position: CGFloat) -> PulleyPosition
    {
        
        if abs(Float(position - bottomDrawer.collapsedHeight)) <= Float.ulpOfOne{
            return .collapsed
        } else if abs(Float(position - bottomDrawer.standardlHeight)) <= Float.ulpOfOne {
            return .standard
        } else if abs(Float(position - bottomDrawer.partialRevealHeight)) <= Float.ulpOfOne {
            return .partiallyRevealed
        } else if abs(Float(position - bottomDrawer.revealHeight)) <= Float.ulpOfOne {
            return .revealed
        } else if abs(Float(position - bottomDrawer.heightOfOpenDrawer)) <= Float.ulpOfOne {
            return .open
        } else{
            return .closed
        }
    }
    
    /**
     Mask backgroundDimmingView layer to avoid drawer background beeing darkened.
     */
    func maskBackgroundDimmingView() {
        
        let cutoutHeight = 2 * bottomDrawer.cornerRadius
        let maskHeight = backgroundDimmingView.bounds.size.height - cutoutHeight - bottomDrawer.scrollView.contentSize.height
        let maskWidth = backgroundDimmingView.bounds.width - pulleySafeAreaInsets.left - pulleySafeAreaInsets.right
        let drawerRect = CGRect(x: pulleySafeAreaInsets.left, y: maskHeight, width: maskWidth, height: bottomDrawer.contentContainer.bounds.height)
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: backgroundDimmingView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        backgroundDimmingView.layer.mask = maskLayer
    }
    
    open func prepareFeedbackGenerator() {
        
        if #available(iOS 10.0, *) {
            if let generator = bottomDrawer.feedbackGenerator as? UIFeedbackGenerator
            {
                generator.prepare()
            }
        }
    }
    
    open func triggerFeedbackGenerator() {
        
        if #available(iOS 10.0, *) {
            
            prepareFeedbackGenerator()
            
            (bottomDrawer.feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
            (bottomDrawer.feedbackGenerator as? UISelectionFeedbackGenerator)?.selectionChanged()
            (bottomDrawer.feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        }
    }
    
    /// Add a gesture recognizer to the drawer scrollview
    ///
    /// - Parameter gestureRecognizer: The gesture recognizer to add
    public func addDrawerGestureRecognizer(gestureRecognizer: UIGestureRecognizer) {
        bottomDrawer.scrollView.addGestureRecognizer(gestureRecognizer)
    }
    
    /// Remove a gesture recognizer from the drawer scrollview
    ///
    /// - Parameter gestureRecognizer: The gesture recognizer to remove
    public func removeDrawerGestureRecognizer(gestureRecognizer: UIGestureRecognizer) {
        bottomDrawer.scrollView.removeGestureRecognizer(gestureRecognizer)
    }
    
    /// Bounce the drawer to get user attention. Note: Only works in .bottomDrawer display mode and when the drawer is in .collapsed or .partiallyRevealed position.
    ///
    /// - Parameters:
    ///   - bounceHeight: The height to bounce
    ///   - speedMultiplier: The multiplier to apply to the default speed of the animation. Note, default speed is 0.75.
    public func bounceDrawer(bounceHeight: CGFloat = 50.0, speedMultiplier: Double = 0.75) {
        
        guard bottomDrawer.drawerPosition == .collapsed || bottomDrawer.drawerPosition == .partiallyRevealed else {
            print("Pulley: Error: You can only bounce the drawer when it's in the collapsed or partially revealed position.")
            return
        }
        
        guard bottomDrawer.currentDisplayMode == .drawer else {
            print("Pulley: Error: You can only bounce the drawer when it's in the .bottomDrawer display mode.")
            return
        }
        
        let drawerStartingBounds = bottomDrawer.scrollView.bounds
        
        // Adapted from https://www.cocoanetics.com/2012/06/lets-bounce/
        let factors: [CGFloat] = [0, 32, 60, 83, 100, 114, 124, 128, 128, 124, 114, 100, 83, 60, 32,
            0, 24, 42, 54, 62, 64, 62, 54, 42, 24, 0, 18, 28, 32, 28, 18, 0]
        
        var values = [CGFloat]()
        
        for factor in factors
        {
            let positionOffset = (factor / 128.0) * bounceHeight
            values.append(drawerStartingBounds.origin.y + positionOffset)
        }
        
        let animation = CAKeyframeAnimation(keyPath: "bounds.origin.y")
        animation.repeatCount = 1
        animation.duration = (32.0/30.0) * speedMultiplier
        animation.fillMode = kCAFillModeForwards
        animation.values = values
        animation.isRemovedOnCompletion = true
        animation.autoreverses = false
        
        bottomDrawer.scrollView.layer.add(animation, forKey: "bounceAnimation")
    }
    
    /**
     Get a frame for moving backgroundDimmingView according to drawer position.
     
     - parameter drawerPosition: drawer position in points
     
     - returns: a frame for moving backgroundDimmingView according to drawer position
     */
    func backgroundDimmingViewFrameForDrawerPosition(_ drawerPosition: CGFloat) -> CGRect {
        let cutoutHeight = (2 * bottomDrawer.cornerRadius)
        var backgroundDimmingViewFrame = backgroundDimmingView.frame
        backgroundDimmingViewFrame.origin.y = 0 - drawerPosition + cutoutHeight

        return backgroundDimmingViewFrame
    }
    
    func syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode() {
        
        guard bottomDrawer.currentDisplayMode == .leftSide else {
            return
        }

        let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
        
        bottomDrawer.contentContainer.frame = CGRect(x: 0.0, y: bottomDrawer.scrollView.bounds.height - lowestStop , width: bottomDrawer.scrollView.bounds.width, height: bottomDrawer.scrollView.contentOffset.y + lowestStop + bottomDrawer.bounceOverflowMargin)
        bottomDrawer.backgroundVisualEffectView?.frame = bottomDrawer.contentContainer.frame
        bottomDrawer.shadowView.frame = bottomDrawer.contentContainer.frame
        
        // Update rounding mask and shadows
        let borderPath = UIBezierPath(roundedRect: bottomDrawer.contentContainer.bounds, byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight], cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius)).cgPath
        
        let cardMaskLayer = CAShapeLayer()
        cardMaskLayer.path = borderPath
        cardMaskLayer.frame = bottomDrawer.contentContainer.bounds
        cardMaskLayer.fillColor = UIColor.white.cgColor
        cardMaskLayer.backgroundColor = UIColor.clear.cgColor
        bottomDrawer.contentContainer.layer.mask = cardMaskLayer
        
        if !bottomDrawer.isAnimatingPosition || borderPath.boundingBox.height < bottomDrawer.shadowView.layer.shadowPath?.boundingBox.height ?? 0.0
        {
            bottomDrawer.shadowView.layer.shadowPath = borderPath
        }
    }

    // MARK: Configuration Updates
    
    /**
     Set the drawer position, with an option to animate.
     
     - parameter position: The position to set the drawer to.
     - parameter animated: Whether or not to animate the change. (Default: true)
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called. (Default: nil)
     */
    public func setDrawerPosition(for drawer: PulleyDrawer, position: PulleyPosition, animated: Bool, completion: PulleyAnimationCompletionBlock? = nil) {
        guard drawer.supportedPositions.contains(position) else {
            
            print("PulleyViewController: You can't set the drawer position to something not supported by the current view controller contained in the drawer. If you haven't already, you may need to implement the PulleyDrawerViewControllerDelegate.")
            return
        }
        
        drawer.drawerPosition = position

        let stopToMoveTo: CGFloat = stopValue(for: drawer.drawerPosition, from: drawer)
        print(drawer.drawerPosition.rawValue)

        let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
        
        let direction: CGFloat = drawer.type == .bottom ? 1.0 : -1.0
        
        triggerFeedbackGenerator()
        
        if animated && self.view.window != nil
        {
            drawer.isAnimatingPosition = true
            UIView.animate(withDuration: drawer.animationDuration, delay: drawer.animationDelay, usingSpringWithDamping: drawer.animationSpringDamping, initialSpringVelocity: drawer.animationSpringInitialVelocity, options: drawer.animationOptions, animations: { [weak self] () -> Void in
                
                drawer.scrollView.setContentOffset(CGPoint(x: 0, y: direction * (stopToMoveTo - lowestStop)), animated: false)
                
                // Move backgroundDimmingView to avoid drawer background being darkened
                self?.backgroundDimmingView.frame = self?.backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo) ?? CGRect.zero
                
                if let drawer = self
                {
                    drawer.delegate?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.pulleySafeAreaInsets.bottom ?? 0.0)
                    (drawer.drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.pulleySafeAreaInsets.bottom ?? 0.0)
                    (drawer.primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.pulleySafeAreaInsets.bottom ?? 0.0)
                    
                    drawer.view.layoutIfNeeded()
                }

                }, completion: { [weak self] (completed) in
                    
                    drawer.isAnimatingPosition = false
                    self?.syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
                    
                    completion?(completed)
            })
        }
        else
        {
            drawer.scrollView.setContentOffset(CGPoint(x: 0, y: direction * (stopToMoveTo - lowestStop)), animated: false)
            
            // Move backgroundDimmingView to avoid drawer background being darkened
            backgroundDimmingView.frame = backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo)
            
            delegate?.drawerPositionDidChange?(drawer: self, bottomSafeArea: pulleySafeAreaInsets.bottom)
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: pulleySafeAreaInsets.bottom)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: pulleySafeAreaInsets.bottom)

            completion?(true)
        }
    }
    
    /**
     Set the drawer position, by default the change will be animated. Deprecated. Recommend switching to the other setDrawerPosition method, this one will be removed in a future release.
     
     - parameter position: The position to set the drawer to.
     - parameter isAnimated: Whether or not to animate the change. Default: true
     */
    @available(*, deprecated)
    public func setDrawerPosition(position: PulleyPosition, isAnimated: Bool = true)
    {
        setDrawerPosition(for: bottomDrawer, position: position, animated: isAnimated)
    }
    
    /**
     Change the current primary content view controller (The one behind the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change. Defaults to true.
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called.
     */
    public func setPrimaryContentViewController(controller: UIViewController, animated: Bool = true, completion: PulleyAnimationCompletionBlock?)
    {
        // Account for transition issue in iOS 11
        controller.view.frame = primaryContentContainer.bounds
        controller.view.layoutIfNeeded()
        
        if animated
        {
            UIView.transition(with: primaryContentContainer, duration: 0.5, options: .transitionCrossDissolve, animations: { [weak self] () -> Void in
                
                self?.primaryContentViewController = controller
                
                }, completion: { (completed) in
                    
                    completion?(completed)
            })
        }
        else
        {
            primaryContentViewController = controller
            completion?(true)
        }
    }
    
    /**
     Change the current primary content view controller (The one behind the drawer). This method exists for backwards compatibility.
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change. Defaults to true.
     */
    public func setPrimaryContentViewController(controller: UIViewController, animated: Bool = true)
    {
        setPrimaryContentViewController(controller: controller, animated: animated, completion: nil)
    }
    
    /**
     Change the current drawer content view controller (The one inside the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change.
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called.
     */
    public func setDrawerContentViewController(controller: UIViewController, animated: Bool = true, completion: PulleyAnimationCompletionBlock?)
    {
        // Account for transition issue in iOS 11
        controller.view.frame = bottomDrawer.contentContainer.bounds
        controller.view.layoutIfNeeded()
        
        if animated
        {
            UIView.transition(with: bottomDrawer.contentContainer, duration: 0.5, options: .transitionCrossDissolve, animations: { [weak self] () -> Void in
                    guard let existingSelf = self else { return }
                    self?.drawerContentViewController = controller
                    self?.setDrawerPosition(for: existingSelf.bottomDrawer, position: self?.bottomDrawer.drawerPosition ?? .collapsed, animated: false)
                }, completion: { (completed) in
                    
                    completion?(completed)
            })
        }
        else
        {
            drawerContentViewController = controller
            setDrawerPosition(for: bottomDrawer, position: bottomDrawer.drawerPosition, animated: false)
            
            completion?(true)
        }
    }
    
    /**
     Change the current drawer content view controller (The one inside the drawer). This method exists for backwards compatibility.
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change.
     */
    public func setDrawerContentViewController(controller: UIViewController, animated: Bool = true)
    {
        setDrawerContentViewController(controller: controller, animated: animated, completion: nil)
    }
    
    /**
     Update the supported drawer positions allows by the Pulley Drawer
     */
    public func setNeedsSupportedDrawerPositionsUpdate()
    {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            bottomDrawer.supportedPositions = drawerVCCompliant.supportedDrawerPositions?() ?? PulleyPosition.all
        }
        else
        {
            bottomDrawer.supportedPositions = PulleyPosition.all
        }
    }
    
    // MARK: Actions
    
    @objc func dimmingViewTapRecognizerAction(gestureRecognizer: UITapGestureRecognizer)
    {
        if gestureRecognizer == dimmingViewTapRecognizer
        {
            if gestureRecognizer.state == .ended
            {
                self.setDrawerPosition(for: bottomDrawer, position: .collapsed, animated: true)
            }
        }
    }
    
    // MARK: Propogate child view controller style / status bar presentation based on drawer state
    
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        get {
            
            if bottomDrawer.drawerPosition == .open {
                return drawerContentViewController
            }
            
            return primaryContentViewController
        }
    }
    
    override open var childViewControllerForStatusBarHidden: UIViewController? {
        get {
            if bottomDrawer.drawerPosition == .open {
                return drawerContentViewController
            }
            
            return primaryContentViewController
        }
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if #available(iOS 10.0, *) {
            coordinator.notifyWhenInteractionChanges { [weak self] context in
                guard let currentPosition = self?.bottomDrawer.drawerPosition else { return }
                guard let existingSelf = self else { return }
                self?.setDrawerPosition(for: existingSelf.bottomDrawer, position: currentPosition, animated: false)
            }
        } else {
            coordinator.notifyWhenInteractionEnds { [weak self] context in
                guard let currentPosition = self?.bottomDrawer.drawerPosition else { return }
                guard let existingSelf = self else { return }
                self?.setDrawerPosition(for: existingSelf.bottomDrawer, position: currentPosition, animated: false)
            }
        }
        
    }
    
    // MARK: PulleyDrawerViewControllerDelegate implementation for nested Pulley view controllers in drawers. Implemented here, rather than an extension because overriding extensions in subclasses isn't good practice. Some developers want to subclass Pulley and customize these behaviors, so we'll move them here.
    
    open func collapsedDrawerHeight(originSafeArea: CGFloat) -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate,
            let collapsedHeight = drawerVCCompliant.collapsedDrawerHeight?(originSafeArea: originSafeArea) {
            return collapsedHeight
        } else {
            return kPulleyDefaultCollapsedHeight + originSafeArea
        }
    }
    
    open func partialRevealDrawerHeight(originSafeArea: CGFloat) -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate,
            let partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight?(originSafeArea: originSafeArea) {
            return partialRevealHeight
        } else {
            return kPulleyDefaultPartialRevealHeight + originSafeArea
        }
    }
    open func revealDrawerHeight(originSafeArea: CGFloat) -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate,
            let revealHeight = drawerVCCompliant.revealDrawerHeight?(originSafeArea: originSafeArea) {
            return revealHeight
        } else {
            return kPulleyDefaultRevealHeight + originSafeArea
        }
    }
    
    open func supportedDrawerPositions() -> [PulleyPosition] {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate,
            let supportedPositions = drawerVCCompliant.supportedDrawerPositions?() {
            return supportedPositions
        } else {
            return PulleyPosition.all
        }
    }
    
    open func drawerPositionDidChange(drawer: PulleyViewController, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: bottomSafeArea)
        }
    }
    
    open func makeUIAdjustmentsForFullscreen(progress: CGFloat, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: bottomSafeArea)
        }
    }
    
    open func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerChangedDistanceFromBottom?(drawer: drawer, distance: distance, bottomSafeArea: bottomSafeArea)
        }
    }
}

extension PulleyViewController: PulleyChestOfDrawers
{
    func calculateOpenDrawerHeight(for drawer: PulleyDrawer) -> CGFloat
    {
        var safeAreaInset: CGFloat
        
        switch drawer.type
        {
        case .bottom:
            safeAreaInset = 20.0
            
        default:
            safeAreaInset = 0.0
        }
        
        if #available(iOS 11.0, *)
        {
            switch drawer.type
            {
            case .bottom:
                safeAreaInset = view.safeAreaInsets.top
            default:
                safeAreaInset = view.safeAreaInsets.bottom
            }
        }
        
        var sideInset: CGFloat = 0.0
        
        switch bottomDrawer.displayMode {
        case .drawer:
            sideInset = 0.0
        case .leftSide:
            sideInset = drawer.topInset
        default:
            sideInset = 0.0
        }
        return (self.view.bounds.height - bottomDrawer.topInset - safeAreaInset - sideInset)
    }
    
    func didSetCurrentDisplayMode(for drawer: PulleyDrawer)
    {
        delegate?.drawerDisplayModeDidChange?(drawer: self, ofType: drawer.type)
        (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: drawer.type)
        (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self, ofType: drawer.type)
    }
    
    func delegateNeedsLayout()
    {
        if self.isViewLoaded
        {
            self.view.setNeedsLayout()
        }
    }
    
    func isPulleyViewLoaded() -> Bool {
        return self.isViewLoaded
    }
    
    func getLowestStop(for drawer: PulleyDrawer) -> CGFloat {
        return getStopList(for: bottomDrawer).min() ?? 0
    }

    
    func getOriginSafeArea(for drawer: PulleyDrawer) -> CGFloat {
        switch drawer.type {
        case .bottom:
            return pulleySafeAreaInsets.bottom
        case .top:
            return pulleySafeAreaInsets.top
        default:
            return 0
        }
    }
    
    func didSetSupportedPositions(for drawer: PulleyDrawer) {
        guard self.isViewLoaded else {
            return
        }
        
        guard drawer.supportedPositions.count > 0 else {
            drawer.supportedPositions = PulleyPosition.all
            return
        }
        
        self.view.setNeedsLayout()
        
        if drawer.supportedPositions.contains(drawer.drawerPosition)
        {
            setDrawerPosition(for: bottomDrawer, position: drawer.drawerPosition, animated: true)
        }
        else
        {
            let lowestDrawerState: PulleyPosition = drawer.supportedPositions.filter({ $0 != .closed }).min { (pos1, pos2) -> Bool in
                return pos1.rawValue < pos2.rawValue
                } ?? .collapsed
            
            setDrawerPosition(for: bottomDrawer, position: lowestDrawerState, animated: false)
        }
        
        bottomDrawer.enforceCanScrollDrawer()
    }
    
   func didSetBackgroundVisualEffectView(for drawer: PulleyDrawer) {
        if let drawerBackgroundVisualEffectView = drawer.backgroundVisualEffectView, self.isViewLoaded
        {
            bottomDrawer.scrollView.insertSubview(drawerBackgroundVisualEffectView, aboveSubview: drawer.shadowView)
            drawerBackgroundVisualEffectView.clipsToBounds = true
            drawerBackgroundVisualEffectView.layer.cornerRadius = bottomDrawer.cornerRadius
            self.view.setNeedsLayout()
        }
    }
    
    func drawerPositionSet() {
        setNeedsStatusBarAppearanceUpdate()
    }
}

extension PulleyViewController: PulleyPassthroughScrollViewDelegate {
    
    func shouldTouchPassthroughScrollView(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> Bool
    {
        return !bottomDrawer.contentContainer.bounds.contains(bottomDrawer.contentContainer.convert(point, from: scrollView))
    }
    
    func viewToReceiveTouch(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> UIView
    {
        if bottomDrawer.currentDisplayMode == .drawer
        {
            if bottomDrawer.drawerPosition == .open
            {
                return backgroundDimmingView
            }
            
            return primaryContentContainer
        }
        else
        {
            if bottomDrawer.contentContainer.bounds.contains(bottomDrawer.contentContainer.convert(point, from: scrollView))
            {
                return drawerContentViewController.view
            }
            
            return primaryContentContainer
        }
    }
}

extension PulleyViewController: UIScrollViewDelegate {

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        var passThroughDrawer: PulleyDrawer?
        let drawer: PulleyDrawer
        
        if let loadedDrawer = passThroughDrawer
        {
            drawer = loadedDrawer
        } else
        {
            drawer = bottomDrawer
        }
        
        let drawerStops: [CGFloat] = drawer.supportedPositions.filter({$0 != .closed}).map({stopValue(for: $0, from: drawer)})
        let currentDrawerPositionStop: CGFloat = stopValue(for: drawer.drawerPosition, from: drawer)
        
        let lowestStop = drawerStops.min() ?? 0
        
        let distanceFromBottomOfView = lastDragTargetContentOffset.y
        
        var currentClosestStop = lowestStop
        
        for currentStop in drawerStops
        {
            if abs(currentStop - distanceFromBottomOfView) < abs(currentClosestStop - distanceFromBottomOfView)
            {
                currentClosestStop = currentStop
            }
        }
        
        let closestValidDrawerPosition: PulleyPosition = drawerPosition(for: currentClosestStop)
        
        let snapModeToUse: PulleySnapMode = closestValidDrawerPosition == drawer.drawerPosition ? drawer.snapMode : .nearestPosition
        
        switch snapModeToUse {
            
        case .nearestPosition:
            
            setDrawerPosition(for: drawer, position: closestValidDrawerPosition, animated: true)
            
        case .nearestPositionUnlessExceeded(let threshold):
            
            let distance = currentDrawerPositionStop - distanceFromBottomOfView
            
            var positionToSnapTo: PulleyPosition = drawer.drawerPosition
            
            if abs(distance) > threshold
            {
                if distance < 0
                {
                    let orderedSupportedDrawerPositions = drawer.supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).filter({ $0 != .closed })
                    
                    for position in orderedSupportedDrawerPositions
                    {
                        if position.rawValue > drawer.drawerPosition.rawValue
                        {
                            positionToSnapTo = position
                            break
                        }
                    }
                }
                else
                {
                    let orderedSupportedDrawerPositions = drawer.supportedPositions.sorted(by: { $0.rawValue > $1.rawValue }).filter({ $0 != .closed })
                    
                    for position in orderedSupportedDrawerPositions
                    {
                        if position.rawValue < drawer.drawerPosition.rawValue
                        {
                            positionToSnapTo = position
                            break
                        }
                    }
                }
            }
            
            setDrawerPosition(for: drawer, position: positionToSnapTo, animated: true)
        }
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        if scrollView == bottomDrawer.scrollView
        {
            lastDragTargetContentOffset = targetContentOffset.pointee
            
            // Halt intertia
            targetContentOffset.pointee = scrollView.contentOffset
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        if scrollView == bottomDrawer.scrollView
        {
            scrollViewDidScroll(for: bottomDrawer, scrollView)
        }
    }
    
    public func scrollViewDidScroll(for drawer: PulleyDrawer, _ scrollView: UIScrollView) {
        
        if scrollView == drawer.scrollView
        {
            let originSafeArea = getOriginSafeArea(for: drawer)
            let revealHeight: CGFloat = (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.revealDrawerHeight?(originSafeArea: originSafeArea) ?? kPulleyDefaultRevealHeight

            let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
            
            print(scrollView.contentOffset.y)
            if (scrollView.contentOffset.y - originSafeArea) > revealHeight - lowestStop && drawer.supportedPositions.contains(.open)
            {
                // Calculate percentage between partial and full reveal
                let fullRevealHeight = drawer.heightOfOpenDrawer
                let progress: CGFloat
                if fullRevealHeight == revealHeight {
                    progress = 1.0
                } else {
                    progress = (scrollView.contentOffset.y - (revealHeight - lowestStop)) / (fullRevealHeight - (revealHeight))
                }

                delegate?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: originSafeArea)
                (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: originSafeArea)
                (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: originSafeArea)
                
                backgroundDimmingView.alpha = progress * backgroundDimmingOpacity
                
                backgroundDimmingView.isUserInteractionEnabled = true
            }
            else
            {
                if backgroundDimmingView.alpha >= 0.001
                {
                    backgroundDimmingView.alpha = 0.0
                    
                    delegate?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: originSafeArea)
                    (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: originSafeArea)
                    (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: originSafeArea)
                    
                    backgroundDimmingView.isUserInteractionEnabled = false
                }
            }
            
            delegate?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: originSafeArea)
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: originSafeArea)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: originSafeArea)
            
            // Move backgroundDimmingView to avoid drawer background beeing darkened
            backgroundDimmingView.frame = backgroundDimmingViewFrameForDrawerPosition(scrollView.contentOffset.y + lowestStop)
            
            syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
        }
    }
}


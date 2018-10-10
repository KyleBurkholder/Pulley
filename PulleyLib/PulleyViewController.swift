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
@objc public protocol PulleyDelegate: class
{
    
    /** This is called after size changes, so if you care about the bottomSafeArea property for custom UI layout, you can use this value.
     * NOTE: It's not called *during* the transition between sizes (such as in an animation coordinator), but rather after the resize is complete.
     */
    @objc optional func drawerPositionDidChange(drawer: PulleyViewController, originSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for when Pulley goes to 'fullscreen'. Bottom safe area is provided for your convenience.
     */
    @objc optional func makeUIAdjustmentsForFullscreen(progress: CGFloat, originSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for changes in the drawer's distance-to-bottom. Bottom safe area is provided for your convenience.
     */
    @objc optional func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, originSafeArea: CGFloat)
    
    /**
     *  Called when the current drawer display mode changes (leftSide vs bottomDrawer). Make UI changes to account for this here.
     */
    @objc optional func drawerDisplayModeDidChange(drawer: PulleyViewController, ofType drawerType: DrawerType)
}

/**
 *  View controllers in the drawer can implement this to receive changes in state or provide values for the different drawer positions.
 */
@objc public protocol PulleyDrawerViewControllerDelegate: PulleyDelegate
{
    
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
@objc public protocol PulleyPrimaryContentControllerDelegate: PulleyDelegate
{
    
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

open class PulleyViewController: UIViewController, PulleyDrawerViewControllerDelegate
{
    // Interface Builder
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var primaryContentContainerView: UIView!
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var drawerContentContainerView: UIView!
    
    //MARK: Internal Properties
    let primaryContentContainer: UIView = UIView()
    let backgroundDimmingView: UIView = UIView()
    var dimmingViewTapRecognizer: UITapGestureRecognizer?
    var lastDragTargetContentOffset: CGPoint = CGPoint.zero

    //MARK: Public Properties
    
    public var bottomDrawer: PulleyDrawer = PulleyDrawer(originSide: .bottom)

    //public let bottomDrawer.bounceOverflowMargin: CGFloat = 20.0

    /// The current content view controller (shown behind the drawer).
    public internal(set) var primaryContentViewController: UIViewController!
    {
        willSet
        {
            guard let controller = primaryContentViewController else
            {
                return
            }
            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        didSet
        {
            guard let controller = primaryContentViewController else
            {
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
    public internal(set) var drawerContentViewController: UIViewController!
    {
        willSet
        {
            guard let controller = drawerContentViewController else
            {
                return
            }
            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        didSet
        {
            guard let controller = drawerContentViewController else
            {
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
    public var bottomSafeSpace: CGFloat
    {
        get
        {
            return pulleySafeAreaInsets.bottom
        }
    }
    
    /// The content view controller and drawer controller can receive delegate events already. This lets another object observe the changes, if needed.
    public weak var delegate: PulleyDelegate?
    
    /// The opaque color of the background dimming view.
    public var backgroundDimmingColor: UIColor = UIColor.black
    {
        didSet
        {
            if self.isViewLoaded
            {
                backgroundDimmingView.backgroundColor = backgroundDimmingColor
            }
        }
    }
    
    /// The maximum amount of opacity when dimming.
    public var backgroundDimmingOpacity: CGFloat = 0.5
    {
        didSet
        {
            if self.isViewLoaded
            {
                self.scrollViewDidScroll(bottomDrawer.scrollView)
            }
        }
    }
    
    /// Access to the safe areas that Pulley is using for layout (provides compatibility for iOS < 11)
    public var pulleySafeAreaInsets: UIEdgeInsets
    {
        var safeAreaBottomInset: CGFloat = 0
        var safeAreaLeftInset: CGFloat = 5
        var safeAreaRightInset: CGFloat = 5
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
        safeAreaLeftInset = 5
        safeAreaRightInset = 5
        return UIEdgeInsets(top: safeAreaTopInset, left: safeAreaLeftInset, bottom: safeAreaBottomInset, right: safeAreaRightInset)
    }
    
    public var dimStartDistance: CGFloat = 500.0
    {
        didSet
        {
            //TODO: Code to update progress
        }
    }
    
    public var dimEndDistance: CGFloat = 300.0
    {
        didSet
        {
            //TODO: Code to update progress
        }
    }
    
        
    
    
    /**
     Initialize the drawer controller programmtically.
     
     - parameter contentViewController: The content view controller. This view controller is shown behind the drawer.
     - parameter drawerViewController:  The view controller to display inside the drawer.
     
     - note: The drawer VC is 20pts too tall in order to have some extra space for the bounce animation. Make sure your constraints / content layout take this into account.
     
     - returns: A newly created Pulley drawer.
     */
    public init(contentViewController: UIViewController, drawerViewController: UIViewController)
    {
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
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override open func loadView()
    {
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
        
        backgroundDimmingView.backgroundColor = backgroundDimmingColor
        backgroundDimmingView.isUserInteractionEnabled = false
        backgroundDimmingView.alpha = 0.0
        //TODO: Remove. This is old backgroundDimmingView
//        backgroundDimmingView.bottomDrawerDelegate = bottomDrawer
        
        dimmingViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PulleyViewController.dimmingViewTapRecognizerAction(gestureRecognizer:)))
        backgroundDimmingView.addGestureRecognizer(dimmingViewTapRecognizer!)
        
        primaryContentContainer.backgroundColor = UIColor.white
        
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(primaryContentContainer)
        self.view.addSubview(backgroundDimmingView)
        //TODO: Remove
//        self.view.addSubview(bottomDrawer.backgroundView)
        self.view.addSubview(bottomDrawer.scrollView)
        
        primaryContentContainer.constrainToParent()
        
        //TODO: Remove
//        bottomDrawer.backgroundView.constrainToParent()
    }
    
    override open func viewDidLoad()
    {
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
    
    override open func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        setNeedsSupportedDrawerPositionsUpdate()
    }
    
    override open func viewDidLayoutSubviews()
    {
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
            // Bottom inset for safe area / bottomLayoutGuide
            if #available(iOS 11, *)
            {
                self.bottomDrawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            } else
            {
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
            
            bottomDrawer.scrollView.addSubview(bottomDrawer.shadowView)
            if let drawerBackgroundVisualEffectView = bottomDrawer.backgroundVisualEffectView
            {
                bottomDrawer.scrollView.addSubview(drawerBackgroundVisualEffectView)
                drawerBackgroundVisualEffectView.layer.cornerRadius = bottomDrawer.cornerRadius
            }
            bottomDrawer.scrollView.addSubview(bottomDrawer.contentContainer)
            bottomDrawer.contentContainer.frame = CGRect(x: 0, y: bottomDrawer.scrollView.bounds.height - lowestStop, width: bottomDrawer.scrollView.bounds.width, height: bottomDrawer.scrollView.bounds.height + bottomDrawer.bounceOverflowMargin)
            bottomDrawer.backgroundVisualEffectView?.frame = bottomDrawer.contentContainer.frame
            bottomDrawer.shadowView.frame = bottomDrawer.contentContainer.frame
            bottomDrawer.scrollView.contentSize = CGSize(width: bottomDrawer.scrollView.bounds.width, height: (bottomDrawer.scrollView.bounds.height - lowestStop) + bottomDrawer.scrollView.bounds.height - pulleySafeAreaInsets.bottom + (bottomDrawer.bounceOverflowMargin - 5.0))
            
            // Update rounding mask and shadows
            let borderPath = UIBezierPath(roundedRect: bottomDrawer.contentContainer.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius)).cgPath
            
            let cardMaskLayer = CAShapeLayer()
            cardMaskLayer.path = borderPath
            cardMaskLayer.frame = bottomDrawer.contentContainer.bounds
            cardMaskLayer.fillColor = UIColor.white.cgColor
            cardMaskLayer.backgroundColor = UIColor.clear.cgColor
            bottomDrawer.contentContainer.layer.mask = cardMaskLayer
            bottomDrawer.shadowView.layer.shadowPath = borderPath
    
            backgroundDimmingView.frame = CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: self.view.bounds.height)
//            backgroundDimmingViewMasked.frame = bottomDrawer.scrollView.convert(bottomDrawer.contentContainer.frame, to: backgroundDimmingView)
//            var nonMaskedFrame = backgroundDimmingView.frame
//            nonMaskedFrame.size.height = backgroundDimmingView.frame.height - backgroundDimmingViewMasked.frame.height
//            backgroundDimmingViewNonMasked.frame = nonMaskedFrame
            // I don't think that I need this? on height. Or I do.
            
            bottomDrawer.scrollView.transform = CGAffineTransform.identity
            backgroundDimmingView.isHidden = false
        }
        else
        {
            // Bottom inset for safe area / bottomLayoutGuide
            if #available(iOS 11, *)
            {
                self.bottomDrawer.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
            } else
            {
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
        
        //TODO: Uncomment if masking func needed. Remove if not
        backgroundDimmingView.setNeedsLayout()
        backgroundDimmingView.layoutIfNeeded()
        //TODO: Remove. This is old backgroundDimmingView
//        backgroundDimmingView.updateMask(with: bottomDrawer.contentContainer.convert(bottomDrawer.contentContainer.bounds, to: backgroundDimmingView))
        setDrawerPosition(for: bottomDrawer, position: bottomDrawer.drawerPosition, animated: false)
    }

    // MARK: Internal State Updates

    func getStopList(for drawer: PulleyDrawer) -> [CGFloat]
    {
        let drawerStops = drawer.supportedPositions.map({stopValue(for: $0, from: drawer)})
        return drawerStops
    }
    
    func stopValue(for position: PulleyPosition, from drawer: PulleyDrawer) -> CGFloat
    {
        switch position
        {
        case .collapsed:
            return drawer.collapsedHeight
            
        case .standard:
            return drawer.standardHeight
            
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
    
    func drawerPosition(for drawer: PulleyDrawer, at position: CGFloat) -> PulleyPosition
    {
        if abs(Float(position - drawer.collapsedHeight)) <= Float.ulpOfOne
        {
            return .collapsed
        } else if abs(Float(position - drawer.standardHeight)) <= Float.ulpOfOne
        {
            return .standard
        } else if abs(Float(position - drawer.partialRevealHeight)) <= Float.ulpOfOne
        {
            return .partiallyRevealed
        } else if abs(Float(position - drawer.revealHeight)) <= Float.ulpOfOne
        {
            return .revealed
        } else if abs(Float(position - drawer.heightOfOpenDrawer)) <= Float.ulpOfOne
        {
            return .open
        } else
        {
            return .closed
        }
    }

    
    func producePath () -> (CAShapeLayer, UIBezierPath)
    {
        var drawerRect = bottomDrawer.scrollView.convert(bottomDrawer.contentContainer.frame, to: self.view)
        print("produce Path drawerRect = \(drawerRect)")
        drawerRect.size.height = drawerRect.size.height
        print("produce Path drawerRect = \(drawerRect)")
//        print("backgroundDimmingView.bound = \(backgroundDimmingView.bounds)")
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: backgroundDimmingView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        return (maskLayer, path)
        
    }
    /**
     Mask backgroundDimmingView layer to avoid drawer background beeing darkened.
     */
    func newMaskBackgroundDimmingView(animated: Bool)
    {
        print("newMaskBackgroundDimmingView called. animated:\(animated)")
//        let cutoutHeight = 2 * bottomDrawer.cornerRadius
//        let maskHeight = bottomDrawer.scrollView.contentSize.height
//        let maskWidth = backgroundDimmingView.bounds.width - pulleySafeAreaInsets.left - pulleySafeAreaInsets.right
        var drawerRect = bottomDrawer.contentContainer.convert(bottomDrawer.contentContainer.bounds, to: self.view)
        drawerRect.size.height = drawerRect.size.height + self.view.bounds.height
        print("drawerRect = \(drawerRect)")
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: bottomDrawer.cornerRadius, height: bottomDrawer.cornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: backgroundDimmingView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        if animated
        {
//            let pathAnimation = CASpringAnimation(keyPath: "path", dampingRatio: bottomDrawer.animationSpringDamping, frequencyResponse: bottomDrawer.animationDuration)
//            pathAnimation.fromValue = (backgroundDimmingView.layer.mask as? CAShapeLayer)!.path
//            pathAnimation.toValue = path.cgPath
//            print("PathAnimation\ndamping = \(pathAnimation.damping)\ninitialVelocity = \(pathAnimation.initialVelocity)\nmass = \(pathAnimation.mass)\nsettlingDuration = \(pathAnimation.settlingDuration)\nstiffness = \(pathAnimation.stiffness)")
//
////            pathAnimation.fillMode = kCAFillModeForwards
////            pathAnimation.isRemovedOnCompletion = false
//            backgroundDimmingView.layer.mask = maskLayer
//            backgroundDimmingView.layer.mask!.add(pathAnimation, forKey: nil)
//            print("pathAnimation started")
        }else
        {
//            backgroundDimmingViewMasked.frame = bottomDrawer.scrollView.convert(bottomDrawer.contentContainer.frame, to: backgroundDimmingView)
//            var nonMaskedFrame = backgroundDimmingView.frame
//            nonMaskedFrame.size.height = backgroundDimmingView.frame.height - backgroundDimmingViewMasked.frame.height
//            backgroundDimmingViewNonMasked.frame = nonMaskedFrame
//        backgroundDimmingViewMasked.layer.mask = maskLayer
        backgroundDimmingView.layer.mask = maskLayer
        }
    }
    
    @available(*, deprecated)
    func maskBackgroundDimmingView()
    {
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
//        backgroundDimmingView.layer.mask = maskLayer
    }
    
    
    
    open func prepareFeedbackGenerator()
    {
        if #available(iOS 10.0, *)
        {
            if let generator = bottomDrawer.feedbackGenerator as? UIFeedbackGenerator
            {
                generator.prepare()
            }
        }
    }
    
    open func triggerFeedbackGenerator()
    {
        if #available(iOS 10.0, *)
        {
            prepareFeedbackGenerator()
            
            (bottomDrawer.feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
            (bottomDrawer.feedbackGenerator as? UISelectionFeedbackGenerator)?.selectionChanged()
            (bottomDrawer.feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        }
    }
    
    /// Add a gesture recognizer to the drawer scrollview
    ///
    /// - Parameter gestureRecognizer: The gesture recognizer to add
    public func addDrawerGestureRecognizer(gestureRecognizer: UIGestureRecognizer)
    {
        bottomDrawer.scrollView.addGestureRecognizer(gestureRecognizer)
    }
    
    /// Remove a gesture recognizer from the drawer scrollview
    ///
    /// - Parameter gestureRecognizer: The gesture recognizer to remove
    public func removeDrawerGestureRecognizer(gestureRecognizer: UIGestureRecognizer)
    {
        bottomDrawer.scrollView.removeGestureRecognizer(gestureRecognizer)
    }
    
    /// Bounce the drawer to get user attention. Note: Only works in .bottomDrawer display mode and when the drawer is in .collapsed or .partiallyRevealed position.
    ///
    /// - Parameters:
    ///   - bounceHeight: The height to bounce
    ///   - speedMultiplier: The multiplier to apply to the default speed of the animation. Note, default speed is 0.75.
    public func bounceDrawer(bounceHeight: CGFloat = 50.0, speedMultiplier: Double = 0.75)
    {
        guard bottomDrawer.drawerPosition == .collapsed || bottomDrawer.drawerPosition == .partiallyRevealed else
        {
            print("Pulley: Error: You can only bounce the drawer when it's in the collapsed or partially revealed position.")
            return
        }
        
        guard bottomDrawer.currentDisplayMode == .drawer else
        {
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
    func backgroundDimmingViewFrameForDrawerPosition(_ drawerPosition: CGFloat) -> CGRect
    {
        let cutoutHeight = (2 * bottomDrawer.cornerRadius)
        var backgroundDimmingViewFrame = backgroundDimmingView.frame
//        backgroundDimmingViewFrame.origin.y = 0 - drawerPosition + cutoutHeight
        backgroundDimmingViewFrame.origin.y = bottomDrawer.contentContainer.convert(bottomDrawer.contentContainer.bounds.origin, to: self.view).y
        
        return backgroundDimmingViewFrame
    }
    
    func syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
    {
        guard bottomDrawer.currentDisplayMode == .leftSide else
        {
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
    
    func alphaDimmingCheck(for drawer: PulleyDrawer, with alpha: CGFloat)
    {
        if alpha > 0
        {
            if drawer.snapShotContentView?.layer.sublayers == nil
            {
                guard let newView = primaryContentContainer.snapshotView(afterScreenUpdates: true) else
                {
                    print("no snapshot avaliable")
                    return
                }
                drawer.snapShotContentView?.layer.addSublayer(newView.layer)
            }
        } else
        {
            drawer.snapShotContentView?.layer.sublayers?.forEach()
                {
                    $0.removeFromSuperlayer()
            }
        }
    }
    
    func updatesnapShotContentFrame(for drawer: PulleyDrawer)
    {
        if let backgroundSnapView = drawer.backgroundSnapShotView
        {
            let snapContentFrame = primaryContentContainer.convert(primaryContentContainer.bounds, to: backgroundSnapView)
            drawer.snapShotContentView?.frame = snapContentFrame
        }
    }
    
    func distance(for drawer: PulleyDrawer) -> CGFloat
    {
        let scrollViewLayerY = drawer.scrollView.layer.presentation()?.bounds.origin.y ?? drawer.scrollView.contentOffset.y
        let drawerContentOffset: CGFloat = drawer.type == DrawerType.bottom ? scrollViewLayerY : drawer.contentOffset -  scrollViewLayerY
        
        return view.bounds.height - drawerContentOffset
    }
    
    // MARK: Configuration Updates
    
    /**
     Set the drawer position, with an option to animate.
     
     - parameter for: The drawer to position.
     - parameter position: The position to set the drawer to.
     - parameter animated: Whether or not to animate the change. (Default: true)
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called. (Default: nil)
     */
    public func setDrawerPosition(for loadDrawer: PulleyDrawer? = nil, position: PulleyPosition, animated: Bool, completion: PulleyAnimationCompletionBlock? = nil)
    {
        let drawer: PulleyDrawer = loadDrawer ?? bottomDrawer
        guard drawer.supportedPositions.contains(position) else
        {
            print("PulleyViewController: You can't set the drawer position to something not supported by the current view controller contained in the drawer. If you haven't already, you may need to implement the PulleyDrawerViewControllerDelegate.")
            return
        }
        let scrollViewLayerY = drawer.scrollView.layer.presentation()?.bounds.origin.y ?? drawer.scrollView.contentOffset.y
        drawer.scrollView.contentOffset.y = scrollViewLayerY
        
        if let snapContentView = drawer.snapShotContentView
        {
            let snapOriginY = snapContentView.layer.presentation()?.frame.origin.y ?? snapContentView.frame.origin.y
            snapContentView.frame.origin.y = snapOriginY
        }
        
        drawer.scrollView.layer.removeAllAnimations()
        drawer.snapShotContentView?.layer.removeAllAnimations()
        updatesnapShotContentFrame(for: drawer)

        
        drawer.drawerPosition = position
        
        let stopToMoveTo: CGFloat = stopValue(for: drawer.drawerPosition, from: drawer)
        let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
        let direction: CGFloat = drawer.type == .bottom ? 1.0 : -1.0
        let contentOffset = direction * (stopToMoveTo - lowestStop - drawer.contentOffset)
        let contentOffsetForSnap = direction * (stopToMoveTo - drawer.contentOffset)
        triggerFeedbackGenerator()
        
        if animated && self.view.window != nil
        {
            drawer.isAnimatingPosition = true
            let animatorID = NSUUID().uuidString
            
            let displayLink = CADisplayLink(target: self, selector: #selector(animationTick(_:)))
            
            CATransaction.begin()
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
            CATransaction.setCompletionBlock({[weak self] in
                print("animation complete")
                drawer.isAnimatingPosition = false
                self?.alphaDimmingCheck(for: drawer, with: self?.backgroundDimmingView.alpha ?? 0.0)
                
                self?.syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
                self?.invalidateDisplayLink(for: displayLink)
                completion?(true)
            })
            
            let mainAnimation = CASpringAnimation(keyPath: "bounds.origin.y", dampingRatio: drawer.animationSpringDamping, frequencyResponse: drawer.animationDuration)
            let maskShiftValue = contentOffset - drawer.scrollView.bounds.origin.y
            print("Drawer type: \(drawer.type.rawValue) contentOffset: \(contentOffset)")
            let movingShiftY = (drawer.scrollView.layer.presentation()?.bounds.origin.y ?? drawer.scrollView.bounds.origin.y) - drawer.scrollView.bounds.origin.y
            mainAnimation.fromValue = drawer.scrollView.bounds.origin.y + movingShiftY
            mainAnimation.toValue = drawer.scrollView.bounds.origin.y + maskShiftValue
            mainAnimation.duration = mainAnimation.settlingDuration
            drawer.scrollView.bounds.origin.y += maskShiftValue
            
            drawer.scrollView.layer.add(mainAnimation, forKey: "bounds shift for drawer \(animatorID)")

            if backgroundDimmingView.alpha > 0, let snapContentView = drawer.snapShotContentView
            {
                let snapShotAnimation = CASpringAnimation(keyPath: "position.y", dampingRatio: drawer.animationSpringDamping, frequencyResponse: drawer.animationDuration)
                snapShotAnimation.fromValue = snapContentView.frame.origin.y
                snapShotAnimation.toValue = snapContentView.frame.origin.y + maskShiftValue
                snapShotAnimation.duration = snapShotAnimation.settlingDuration
                snapContentView.frame.origin.y += maskShiftValue
                
                snapContentView.layer.add(snapShotAnimation, forKey: "origin shift for snapContent \(animatorID)")
            }

            CATransaction.commit()
            displayLink.add(to: .main, forMode: .defaultRunLoopMode)
        }
        else
        {
            drawer.scrollView.setContentOffset(CGPoint(x: 0, y: contentOffset), animated: false)
            
            backgroundDimmingView.setNeedsLayout()
            
            delegate?.drawerPositionDidChange?(drawer: self, originSafeArea: pulleySafeAreaInsets.bottom)
            drawer.drawerDelegate?.drawerPositionDidChange?(drawer: self, originSafeArea: pulleySafeAreaInsets.bottom)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: self, originSafeArea: pulleySafeAreaInsets.bottom)

            completion?(true)
        }
    }
    
    func invalidateDisplayLink(for displayLink: CADisplayLink)
    {
       displayLink.invalidate()
    }
    
    @objc func animationTick(_ displayLink: CADisplayLink)
    {
        let drawer = bottomDrawer
        let scrollViewLayerY = drawer.scrollView.layer.presentation()?.bounds.origin.y ?? drawer.scrollView.contentOffset.y
        let drawerContentOffset: CGFloat = drawer.type == DrawerType.bottom ? scrollViewLayerY : drawer.contentOffset - scrollViewLayerY
        if distance(for: drawer) < dimStartDistance
        {
        var progress: CGFloat = (dimStartDistance - distance(for: drawer)) / (dimStartDistance - dimEndDistance) //backgroundDimmingView.dimProgress()
        progress = progress > 1.0 ? 1.0 : progress
            backgroundDimmingView.alpha = progress * backgroundDimmingOpacity
        } else
        {
            backgroundDimmingView.alpha = 0.0
            alphaDimmingCheck(for: drawer, with: backgroundDimmingView.alpha)
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
    
    open func drawerPositionDidChange(drawer: PulleyViewController, originSafeArea bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerPositionDidChange?(drawer: drawer, originSafeArea: bottomSafeArea)
        }
    }
    
    open func makeUIAdjustmentsForFullscreen(progress: CGFloat, originSafeArea bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.makeUIAdjustmentsForFullscreen?(progress: progress, originSafeArea: bottomSafeArea)
        }
    }
    
    open func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, originSafeArea bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerChangedDistanceFromBottom?(drawer: drawer, distance: distance, originSafeArea: bottomSafeArea)
        }
    }
}

extension PulleyViewController: PulleyChestOfDrawers
{
    func producePrimaryView() -> UIView
    {
        return primaryContentContainer
    }
    
    func calculateOpenDrawerHeight(for drawer: PulleyDrawer) -> CGFloat
    {
        var safeAreaInset: CGFloat
        
        switch drawer.type
        {
        case .bottom:
            safeAreaInset = pulleySafeAreaInsets.top
            
        default:
            safeAreaInset = pulleySafeAreaInsets.bottom
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
        return (self.view.bounds.height - drawer.topInset - safeAreaInset - sideInset)
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
            setDrawerPosition(for: drawer, position: drawer.drawerPosition, animated: true)
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
//            drawer.scrollView.insertSubview(drawerBackgroundVisualEffectView, aboveSubview: drawer.shadowView)
//            drawerBackgroundVisualEffectView.clipsToBounds = true
//            drawerBackgroundVisualEffectView.layer.cornerRadius = drawer.cornerRadius
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
        guard let drawer = scrollView.parentDrawer else { return false }
        return !drawer.contentContainer.bounds.contains(drawer.contentContainer.convert(point, from: scrollView))
    }
    
    func viewToReceiveTouch(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> UIView
    {
        let drawer = scrollView.parentDrawer ?? bottomDrawer
        if drawer.currentDisplayMode == .drawer
        {
            if drawer.type == DrawerType.top
            {
                return bottomDrawer.scrollView
            }
            if backgroundDimmingView.alpha > 0.0
            {
                return backgroundDimmingView
            }
            
            return primaryContentContainer
        }
        else
        {
            if drawer.contentContainer.bounds.contains(drawer.contentContainer.convert(point, from: scrollView))
            {
                //I haven't tested if this works or not.
                return drawer.contentContainer.subviews.first ?? drawerContentViewController.view
            }
            
            return primaryContentContainer
        }
    }
}

extension PulleyViewController: UIScrollViewDelegate {

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("scrollViewDidEndDragging")
        let drawer: PulleyDrawer = (scrollView as? PulleyPassthroughScrollView)?.parentDrawer ?? bottomDrawer
        
        let drawerStops: [CGFloat] = drawer.supportedPositions.filter({$0 != .closed}).map({stopValue(for: $0, from: drawer)})
        let currentDrawerPositionStop: CGFloat = stopValue(for: drawer.drawerPosition, from: drawer)
        
        let lowestStop = drawerStops.min() ?? 0
        
//        print(lastDragTargetContentOffset.y)
//        print(drawer.contentOffset)
//        print(lowestStop)
        let distanceFromOriginOfView = abs(lastDragTargetContentOffset.y - drawer.contentOffset)
        
        var currentClosestStop = lowestStop
        
        for currentStop in drawerStops
        {
            if abs(currentStop - distanceFromOriginOfView) < abs(currentClosestStop - distanceFromOriginOfView)
            {
                currentClosestStop = currentStop
            }
        }
        
        let closestValidDrawerPosition: PulleyPosition = drawerPosition(for: drawer, at: currentClosestStop)
        
        let snapModeToUse: PulleySnapMode = closestValidDrawerPosition == drawer.drawerPosition ? drawer.snapMode : .nearestPosition
        
        switch snapModeToUse {
            
        case .nearestPosition:
            
            setDrawerPosition(for: drawer, position: closestValidDrawerPosition, animated: true)
            
        case .nearestPositionUnlessExceeded(let threshold):
            
            let distance = currentDrawerPositionStop - distanceFromOriginOfView
            
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
        
        guard (scrollView as? PulleyPassthroughScrollView)?.parentDrawer != nil else { return }
        
            lastDragTargetContentOffset = targetContentOffset.pointee
            print(lastDragTargetContentOffset)
            // Halt intertia
            targetContentOffset.pointee = scrollView.contentOffset

    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView)
    {

        let drawer = (scrollView as? PulleyPassthroughScrollView)?.parentDrawer ?? bottomDrawer
        let originSafeArea = getOriginSafeArea(for: drawer)
        
        let scrollViewLayerY = drawer.isAnimatingPosition ? (scrollView.layer.presentation()?.bounds.origin.y ?? scrollView.contentOffset.y) : scrollView.contentOffset.y
        scrollView.contentOffset.y = scrollViewLayerY
        
        if let snapContentView = drawer.snapShotContentView
        {
            let snapOriginY = snapContentView.layer.presentation()?.frame.origin.y ?? snapContentView.frame.origin.y
            snapContentView.frame.origin.y = snapOriginY
        }
        
        
        
        drawer.isAnimatingPosition = false
        drawer.scrollView.layer.removeAllAnimations()
        drawer.snapShotContentView?.layer.removeAllAnimations()
        
        
        //TODO: This might not work with two drawers
        
        let lowestStop = getStopList(for: bottomDrawer).min() ?? 0
       
        let drawerContentOffset: CGFloat = drawer.type == DrawerType.bottom ? scrollView.contentOffset.y : drawer.contentOffset - scrollViewLayerY
        
        print(drawer.type == DrawerType.bottom ? (view.bounds.height - drawerContentOffset) : drawerContentOffset )
        
        if distance(for: drawer) < dimStartDistance
        {
            
            var progress: CGFloat = (dimStartDistance - distance(for: drawer)) / (dimStartDistance - dimEndDistance) //backgroundDimmingView.dimProgress()
            progress = progress > 1.0 ? 1.0 : progress
//            print(progress)
            
            delegate?.makeUIAdjustmentsForFullscreen?(progress: progress, originSafeArea: originSafeArea)
            drawer.drawerDelegate?.makeUIAdjustmentsForFullscreen?(progress: progress, originSafeArea: originSafeArea)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: progress, originSafeArea: originSafeArea)
            
            backgroundDimmingView.alpha = progress * backgroundDimmingOpacity
            alphaDimmingCheck(for: drawer, with: backgroundDimmingView.alpha)
            updatesnapShotContentFrame(for: drawer)
            
            backgroundDimmingView.isUserInteractionEnabled = true
        }
        else
        {
            if backgroundDimmingView.alpha >= 0.001
            {
                backgroundDimmingView.alpha = 0.0
                alphaDimmingCheck(for: drawer, with: backgroundDimmingView.alpha)
                
                delegate?.makeUIAdjustmentsForFullscreen?(progress: 0.0, originSafeArea: originSafeArea)
                drawer.drawerDelegate?.makeUIAdjustmentsForFullscreen?(progress: 0.0, originSafeArea: originSafeArea)
                (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: 0.0, originSafeArea: originSafeArea)
                
                backgroundDimmingView.isUserInteractionEnabled = false
            }
        }
        
        //TODO: Needs updated?
        delegate?.drawerChangedDistanceFromBottom?(drawer: self, distance: drawerContentOffset + lowestStop, originSafeArea: originSafeArea)
        drawer.drawerDelegate?.drawerChangedDistanceFromBottom?(drawer: self, distance: drawerContentOffset + lowestStop, originSafeArea: originSafeArea)
        (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerChangedDistanceFromBottom?(drawer: self, distance: drawerContentOffset + lowestStop, originSafeArea: originSafeArea)
        
        syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
    }

}


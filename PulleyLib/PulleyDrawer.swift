//
//  PulleyDrawer.swift
//  Pulley
//
//  Created by Kyle Burkholder on 7/30/18.
//  Copyright © 2018 52inc. All rights reserved.
//

import UIKit

protocol PulleyChestOfDrawers: AnyObject
{
    func drawerPositionSet()
    
    func didSetBackgroundVisualEffectView(for drawer: PulleyDrawer)
    
    func getLowestStop(for drawer: PulleyDrawer) -> CGFloat
    
    func getOriginSafeArea(for drawer: PulleyDrawer) -> CGFloat
    
    func isPulleyViewLoaded() -> Bool
    
    func delegateNeedsLayout()
    
    func didSetSupportedPositions(for drawer: PulleyDrawer)
    
    func didSetCurrentDisplayMode(for drawer: PulleyDrawer)
    
    func calculateOpenDrawerHeight(for drawer: PulleyDrawer) -> CGFloat
}

public class PulleyDrawer
{
    let contentContainer: UIView = UIView()
    let shadowView: UIView = UIView()
    let scrollView: PulleyPassthroughScrollView = PulleyPassthroughScrollView()
    let type: DrawerType
    
    weak var delegate: PulleyChestOfDrawers?
    
    weak var drawerDelegate: PulleyDrawerViewControllerDelegate?
    
    init(originSide type: DrawerType)
    {
        self.type = type
        
        scrollView.bounces = false
        scrollView.clipsToBounds = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        scrollView.delaysContentTouches = delaysContentTouches
        scrollView.canCancelContentTouches = canCancelContentTouches
        
        //TODO: Remove the coloring of the the scrollView when I get everything working
        switch self.type {
        case .bottom:
                    scrollView.backgroundColor = UIColor.red
        case .top:
                    scrollView.backgroundColor = UIColor.purple
        default:
            return
        }

        scrollView.decelerationRate = UIScrollViewDecelerationRateFast
        scrollView.scrollsToTop = false
        
        shadowView.layer.shadowOpacity = shadowOpacity
        shadowView.layer.shadowRadius = shadowRadius
        shadowView.backgroundColor = UIColor.clear
        
        contentContainer.backgroundColor = UIColor.clear
        
        backgroundVisualEffectView?.clipsToBounds = true
        
        scrollView.addSubview(shadowView)
        
        if let drawerBackgroundVisualEffectView = backgroundVisualEffectView
        {
            scrollView.addSubview(drawerBackgroundVisualEffectView)
            drawerBackgroundVisualEffectView.layer.cornerRadius = cornerRadius
        }
        
        scrollView.addSubview(contentContainer)
        
    }
    
    //MARK: drawerPosition properties
    
    /// The current position of the drawer.
    public internal(set) var drawerPosition: PulleyPosition = .collapsed
    {
        didSet {
            delegate?.drawerPositionSet()
        }
    }
    
    /// The currently rendered display mode for Pulley. This will match displayMode unless you have it set to 'automatic'. This will provide the 'actual' display mode (never automatic).
    public internal(set) var currentDisplayMode: PulleyDisplayMode = .automatic {
        didSet {
            delegate?.delegateNeedsLayout()
            if oldValue != currentDisplayMode
            {
                delegate?.didSetCurrentDisplayMode(for: self)
            }
        }
    }
    
    /// The drawer snap mode
    public var snapMode: PulleySnapMode = .nearestPositionUnlessExceeded(threshold: 20.0)
    
    /// Whether the drawer's position can be changed by the user. If set to `false`, the only way to move the drawer is programmatically. Defaults to `true`.
    public var allowsUserDrawerPositionChange: Bool = true
    {
        didSet
        {
            enforceCanScrollDrawer()
        }
    }
    
    /// This setting allows you to enable/disable Pulley automatically insetting the drawer on the left/right when in 'bottomDrawer' display mode in a horizontal orientation on a device with a 'notch' or other left/right obscurement.
    public var adjustDrawerHorizontalInsetToSafeArea: Bool = true
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
        }
    }
    
    /// The starting position for the drawer when it first loads
    public var initialDrawerPosition: PulleyPosition = .collapsed
    
    var collapsedHeight: CGFloat {
        if let originSafeArea = delegate?.getOriginSafeArea(for: self)
        {
            return drawerDelegate?.collapsedDrawerHeight?(originSafeArea: originSafeArea) ?? kPulleyDefaultCollapsedHeight
        }
        return kPulleyDefaultCollapsedHeight
    }
    
    var standardlHeight: CGFloat {
        if let originSafeArea = delegate?.getOriginSafeArea(for: self)
        {
            return drawerDelegate?.standardDrawerHeight?(originSafeArea: originSafeArea) ?? kPulleyDefaultStandardHeight
        }
        return kPulleyDefaultStandardHeight
    }
    
    var partialRevealHeight: CGFloat {
        if let originSafeArea = delegate?.getOriginSafeArea(for: self)
        {
            return drawerDelegate?.partialRevealDrawerHeight?(originSafeArea: originSafeArea) ?? kPulleyDefaultPartialRevealHeight
        }
        return kPulleyDefaultPartialRevealHeight
    }
    
    var revealHeight: CGFloat {
        if let originSafeArea = delegate?.getOriginSafeArea(for: self)
        {
            return drawerDelegate?.revealDrawerHeight?(originSafeArea: originSafeArea) ?? kPulleyDefaultRevealHeight
        }
        return kPulleyDefaultRevealHeight
    }
    
    // The visible height of the drawer. Useful for adjusting the display of content in the main content view.
    public var visibleDrawerHeight: CGFloat {
        if drawerPosition == .closed {
            return 0.0
        } else {
            return scrollView.bounds.height
        }
    }
    
    /// The display mode for Pulley. Default is 'bottomDrawer', which preserves the previous behavior of Pulley. If you want it to adapt automatically, choose 'automatic'. The current display mode is available by using the 'currentDisplayMode' property.
    public var displayMode: PulleyDisplayMode = .drawer
    {
        didSet {
            delegate?.delegateNeedsLayout()
        }
    }
    
    /// The height of the open position for the drawer
    var heightOfOpenDrawer: CGFloat {
        return delegate?.calculateOpenDrawerHeight(for: self) ?? 0.0
    }
    
    /// The drawer positions supported by the drawer
    var supportedPositions: [PulleyPosition] = PulleyPosition.all {
        didSet {
            delegate?.didSetSupportedPositions(for: self)
        }
    }
    
    //MARK: Margin properties
    public let bounceOverflowMargin: CGFloat = 20.0
    
    /// The inset from the top safe area when fully open. NOTE: When in 'leftSide' displayMode this is the distance to the bottom of the screen.
    public var topInset: CGFloat = 20.0
    {
        didSet
        {
                delegate?.delegateNeedsLayout()
        }
    }
    
    /// When in 'leftSide' displayMode, this is used to calculate the left inset from the edge of the screen.
    public var panelInsetLeft: CGFloat = 10.0
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
        }
    }
    
    /// When in 'leftSide' displayMode, this is used to calculate the top inset from the edge of the screen.
    public var panelInsetTop: CGFloat = 30.0
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
        }
    }
    
    /// The width of the panel in leftSide displayMode
    public var panelWidth: CGFloat = 325.0
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
        }
    }
    
    /// The corner radius for the drawer.
    public var cornerRadius: CGFloat = 13.0
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
            backgroundVisualEffectView?.layer.cornerRadius = cornerRadius
        }
    }
    
    /// The opacity of the drawer shadow.
    public var shadowOpacity: Float = 0.1
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
            shadowView.layer.shadowOpacity = shadowOpacity
            
        }
    }
    
    /// The radius of the drawer shadow.
    public var shadowRadius: CGFloat = 3.0
    {
        didSet
        {
            delegate?.delegateNeedsLayout()
            shadowView.layer.shadowRadius = shadowRadius
        }
    }
    
    //MARK: scrollView properties
    
    /// The drawer scrollview's delaysContentTouches setting
    public var delaysContentTouches: Bool = true
    {
        didSet
        {
            scrollView.delaysContentTouches = delaysContentTouches
        }
    }
    
    /// The drawer scrollview's canCancelContentTouches setting
    public var canCancelContentTouches: Bool = true
    {
        didSet
        {
            scrollView.canCancelContentTouches = canCancelContentTouches
        }
    }
    
    /// Get all gesture recognizers in the drawer scrollview
    public var gestureRecognizers: [UIGestureRecognizer]
    {
        get
        {
            return scrollView.gestureRecognizers ?? [UIGestureRecognizer]()
        }
    }
    
    /// Get the drawer scrollview's pan gesture recognizer
    public var panGestureRecognizer: UIPanGestureRecognizer
    {
        get
        {
            return scrollView.panGestureRecognizer
        }
    }
    
    //MARK: Animation constants
    
    /// The animation duration for setting the drawer position
    public var animationDuration: TimeInterval = 0.3
    
    /// The animation delay for setting the drawer position
    public var animationDelay: TimeInterval = 0.0
    
    /// The spring damping for setting the drawer position
    public var animationSpringDamping: CGFloat = 0.75
    
    /// The spring's initial velocity for setting the drawer position
    public var animationSpringInitialVelocity: CGFloat = 0.0
    
    /// The animation options for setting the drawer position
    public var animationOptions: UIViewAnimationOptions = [.curveEaseInOut]
    
    public var isAnimatingPosition: Bool = false
    
    
    //MARK: Misc properties
    
    // The feedback generator to use for drawer positon changes. Note: This is 'Any' to preserve iOS 9 compatibilty. Assign a UIFeedbackGenerator to this property. Anything else will be ignored.
    public var feedbackGenerator: Any?
    
    /// Get the current drawer distance. This value is equivalent in nature to the one delivered by PulleyDelegate's `drawerChangedDistanceFromBottom` callback.
    public var distanceFromOrigin: (distance: CGFloat, originSafeArea: CGFloat) {
        
        if let lowestStop = delegate?.getLowestStop(for: self), let originSafeArea = delegate?.getOriginSafeArea(for: self), let loaded = delegate?.isPulleyViewLoaded(), loaded
        {
            
            return (distance: scrollView.contentOffset.y + lowestStop, originSafeArea: originSafeArea)
        }
        
        return (distance: 0.0, originSafeArea: 0.0)
    }
    
    /// The background visual effect layer for the drawer. By default this is the extraLight effect. You can change this if you want, or assign nil to remove it.
    public var backgroundVisualEffectView: UIVisualEffectView? = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight)) {
        willSet {
            backgroundVisualEffectView?.removeFromSuperview()
        }
        didSet {
            delegate?.didSetBackgroundVisualEffectView(for: self)
        }
    }
    
    //MARK: Internal functions
    
    func enforceCanScrollDrawer()
    {
        scrollView.isScrollEnabled = allowsUserDrawerPositionChange && supportedPositions.count > 1
    }
}
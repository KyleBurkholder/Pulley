//
//  BackgroundMaskedView.swift
//  Pulley
//
//  Created by Kyle Burkholder on 9/8/18.
//  Copyright © 2018 52inc. All rights reserved.
//

import UIKit
protocol DrawerDelegate : AnyObject
{
    func returnDrawerOverFlowHeight() -> CGFloat
    
    func returnDrawerPosition() -> CGFloat
    
    func returnCornerRadius() -> CGFloat
}

class BackgroundMaskedView: UIView
{
    
    //MARK: Properties
    
    var precentStarDim: CGFloat = 0.5
    
    var precentMaxDim: CGFloat = 0.4
    
    var isAnimating: Bool = false
    
    var bottomDrawerCompletionHander: (() -> Void)?
    
    var topDrawerCompletionHander: (() -> Void)?
    
    //TODO: Remove when done debugging
    
    var numberOfTimesAnimated: Int = 0
    
    var heightStartDim: CGFloat
    {
        return self.bounds.height * precentStarDim
    }
    
    var heightMaxDim: CGFloat
    {
        return self.bounds.height * precentMaxDim
    }
    
    var fillPositionY: CGFloat
    {
        var position = self.bounds.height - fillView.bounds.height
        position -= bottomDrawerHeight
        return position
    }
    
    let fillView: UIView =
    {
        let newView = UIView()
        newView.backgroundColor = UIColor.green
        newView.clipsToBounds = true
        newView.layer.anchorPoint.y = 0.0
        return newView
    }()
    let bottomDrawerView: UIView =
    {
        let newView = UIView()
        newView.backgroundColor = UIColor.cyan
        newView.clipsToBounds = true
        newView.layer.anchorPoint.y = 0.0
        return newView
    }()
    var topDrawerView: UIView?
    
    var subviewsBackgroundColor: UIColor?
    {
        get
        {
            if fillView.backgroundColor != bottomDrawerView.backgroundColor
            {
                print("The subview backgroundColors are out of sync.")
            }
           return fillView.backgroundColor
        }
        set
        {
//            fillView.backgroundColor = newValue
//            bottomDrawerView.backgroundColor = newValue
//            topDrawerView.backgroundColor = newValue
        }

    }
    
    var subviewsAlpha: CGFloat
    {
        get
        {
            if fillView.alpha != bottomDrawerView.alpha
            {
                print("The subview alphas are out of sync.")
            }
            return fillView.alpha
        }
        set
        {
            fillView.alpha = newValue
            bottomDrawerView.alpha = newValue
            topDrawerView?.alpha = newValue
        }
    }
    
    var bottomDrawerHeight: CGFloat
    {
        guard let height = bottomDrawerDelegate?.returnDrawerPosition() else
        {
            print("bottomDrawerDelegate is nil")
            return 0.0
        }
        return height
    }
    
    var bottomDrawerOverFlow: CGFloat
    {
        guard let overflow = bottomDrawerDelegate?.returnDrawerOverFlowHeight() else
        {
            print("bottomDrawerDelegate is nil")
            return 0.0
        }
        return overflow
    }
    
    var topDrawerHeight: CGFloat
    {
        guard let height = topDrawerDelegate?.returnDrawerPosition() else
        {
            print("topDrawerDelegate is nil")
            return 0.0
        }
        return height
    }
    
    var topDrawerOverFlow: CGFloat
    {
        guard let overflow = topDrawerDelegate?.returnDrawerOverFlowHeight() else
        {
            print("topDrawerDelegate is nil")
            return 0.0
        }
        return overflow
    }
    
    //MARK: Drawer delegate properties
    
    weak var bottomDrawerDelegate: DrawerDelegate?
    
    weak var topDrawerDelegate: DrawerDelegate?
    
    //MARK: Override functions
    
    override func layoutSubviews()
    {
        print("BackgroundMaskedView layoutSubviews called")
        
        self.addSubview(fillView)
        self.addSubview(bottomDrawerView)
        let overflowbounds = self.bounds.applying(CGAffineTransform(scaleX: 1.0, y: 3.0)).offsetBy(dx: 0.0, dy: -self.bounds.height)
        let dividedRects = overflowbounds.divided(atDistance: self.bounds.height + bottomDrawerHeight, from: .maxYEdge)
        
        bottomDrawerView.frame = dividedRects.slice
        print("bottomDrawerView.frame: \(bottomDrawerView.frame)")
        
        if let topView = topDrawerView
        {
            self.addSubview(topView)
            let secondDividedRects = dividedRects.remainder.divided(atDistance: self.bounds.height + topDrawerHeight, from: .minYEdge)
            topView.frame = secondDividedRects.slice
            fillView.frame = secondDividedRects.remainder
            print("topDrawerView.frame: \(topView.frame)")
            print("fillView.frame: \(fillView.frame)")
        }
        else
        {
            fillView.frame = dividedRects.remainder
        }
        
    }
    
    //TODO: Replace all view setups with this when I'm done debugging
    func setupView() -> UIView
    {
        let newView = UIView()
        newView.backgroundColor = UIColor.orange
        newView.clipsToBounds = true
        newView.layer.anchorPoint.y = 0.0
        return newView
    }
    
    func updateMask(with drawerMaskRect: CGRect)
    {
        print("BackgroundMaskedView updateMask called")
        var drawerRect = self.convert(drawerMaskRect, to: bottomDrawerView)
        let cornerRadius = bottomDrawerDelegate?.returnCornerRadius() ?? 15.0
        drawerRect.size.height = bottomDrawerView.bounds.height
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: bottomDrawerView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        bottomDrawerView.layer.mask = maskLayer
    }
    func updateTopMask(with drawerMaskRect: CGRect)
    {
        guard let topView = topDrawerView  else
        {
            print("topDrawerView is nil")
            return
        }
        print("BackgroundMaskedView updateTopMask called")
        var drawerRect = self.convert(drawerMaskRect, to: topView)
        let cornerRadius = topDrawerDelegate?.returnCornerRadius() ?? 15.0
        drawerRect.origin.x = topView.frame.origin.y
        drawerRect.size.height = topView.bounds.height
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.bottomLeft, .bottomRight],
                                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: bottomDrawerView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        bottomDrawerView.layer.mask = maskLayer
    }
    
    func animateMask(for drawer: PulleyDrawer, points: CGFloat)
    {
        numberOfTimesAnimated += 1
        print("Animation number \(numberOfTimesAnimated)")
        isAnimating = true
        let dimmingDrawerView: UIView
        let drawerMove: CGFloat
        let uniqueString = NSUUID().uuidString
        var fillViewCompletion:  (() -> Void)? = nil
        print(uniqueString.description)
        print(points)
        
        switch drawer.type
        {
        case .bottom:
            
            drawerMove = points
            
            dimmingDrawerView = bottomDrawerView
        case .top:
            
            drawerMove = -points
            
            guard let topDrawerView = self.topDrawerView else
            {
                print("topDrawerView is nil")
                return
            }
            
            
            let fillPositionAnimation = CASpringAnimation(keyPath: "position.y", dampingRatio: drawer.animationSpringDamping, frequencyResponse: drawer.animationDuration)
            fillPositionAnimation.isAdditive = true
            fillPositionAnimation.fromValue = 0.0
            fillPositionAnimation.toValue = -points
            fillPositionAnimation.duration = fillPositionAnimation.settlingDuration
            
            fillPositionAnimation.fillMode = kCAFillModeForwards
            fillPositionAnimation.isRemovedOnCompletion = false
            
            fillView.layer.add(fillPositionAnimation, forKey: "position of fillView \(uniqueString)")
            
            fillViewCompletion =
                {[weak self, points] in
                    guard let safeSelf = self else
                    {
                        print("Can't Complete fillViewPositionCompletion because self is gone")
                        return
                    }
                safeSelf.fillView.layer.position.y = safeSelf.fillView.layer.position.y + points
                safeSelf.fillView.layer.removeAnimation(forKey: "position of fillView \(uniqueString)")
            }
            
            dimmingDrawerView = topDrawerView
        default:
            return
        }
        
        let drawerAnimation = CASpringAnimation(keyPath: "position.y", dampingRatio: drawer.animationSpringDamping, frequencyResponse: drawer.animationDuration)
        drawerAnimation.isAdditive = true
        drawerAnimation.fromValue = 0.0
        drawerAnimation.toValue = -points
        drawerAnimation.duration = drawerAnimation.settlingDuration
        
        drawerAnimation.fillMode = kCAFillModeForwards
        drawerAnimation.isRemovedOnCompletion = false
        
        dimmingDrawerView.layer.add(drawerAnimation, forKey: "position of drawer \(uniqueString)")
        
        
        let fillBoundsAnimation = CASpringAnimation(keyPath: "bounds.size.height", dampingRatio: drawer.animationSpringDamping, frequencyResponse: drawer.animationDuration)
        fillBoundsAnimation.isAdditive = true
        fillBoundsAnimation.fromValue = 0.0
        fillBoundsAnimation.toValue = -drawerMove
        fillBoundsAnimation.duration = fillBoundsAnimation.settlingDuration
        
        fillBoundsAnimation.fillMode = kCAFillModeForwards
        fillBoundsAnimation.isRemovedOnCompletion = false
        
        fillView.layer.add(fillBoundsAnimation, forKey: "bounds for fillView \(uniqueString)")

        let completionHander =
            { [weak self, points] in
                
                print("completionChanges")
                fillViewCompletion?()
                guard let safeSelf = self else
                {
                    print("Can't Complete fillViewPositionCompletion because self is gone")
                    return
                }
                print(dimmingDrawerView.layer.position.y)
                dimmingDrawerView.layer.position.y = dimmingDrawerView.layer.position.y - points
                dimmingDrawerView.layer.removeAnimation(forKey: "position of drawer \(uniqueString)")
                print(dimmingDrawerView.layer.position.y)
                safeSelf.fillView.layer.bounds.size.height = safeSelf.fillView.layer.bounds.size.height + drawerMove
                safeSelf.fillView.layer.removeAnimation(forKey: "bounds for fillView \(uniqueString)")
        }
        switch drawer.type {
        case .bottom:
            bottomDrawerCompletionHander = completionHander
        case .top:
            topDrawerCompletionHander = completionHander
        default:
            return
        }
    }
    
    func dimProgress() -> CGFloat
    {
        //TODO: When second drawer is added this will need to be updead
        //Current the fillView goes off the screen but this wont be the case with two drawers.
        let dimViewHeight = fillView.bounds.height - self.bounds.height
        switch dimViewHeight
        {
        case let x where x > heightStartDim:
            return 0.0
        case let x where x <= heightMaxDim:
            return 1.0
        default:
            return (heightStartDim - dimViewHeight) / (heightStartDim - heightMaxDim)
        }
    }
}


//
//  CASpringAnimation.swift
//  Pulley
//
//  Created by Kyle Burkholder on 8/30/18.
//  Copyright © 2018 52inc. All rights reserved.
//

import UIKit

extension CASpringAnimation
{
    public convenience init(keyPath: String ,dampingRatio: CGFloat, frequencyResponse: CGFloat) {
        precondition(dampingRatio >= 0)
        precondition(frequencyResponse > 0)
        
        let mass = 1 as CGFloat
        let stiffness = pow(2 * .pi / frequencyResponse, 2) * mass
        let damping = 4 * .pi * dampingRatio * mass / frequencyResponse
        
        self.init(keyPath: keyPath)
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
        self.initialVelocity = 0.0
    }
}

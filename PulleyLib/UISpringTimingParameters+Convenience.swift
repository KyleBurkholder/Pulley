//
//  UISpringTimingParameters+convientInit.swift
//  Pulley_Playground
//
//  Created by Kyle Burkholder on 8/30/18.
//  Copyright © 2018 Kyle Burkholder. All rights reserved.
//

import UIKit
@available(iOS 10.0, *)
extension UISpringTimingParameters {
    public convenience init(dampingRatio: CGFloat, frequencyResponse: CGFloat) {
        precondition(dampingRatio >= 0)
        precondition(frequencyResponse > 0)
        
        let mass = 1 as CGFloat
        let stiffness = pow(2 * .pi / frequencyResponse, 2) * mass
        let damping = 4 * .pi * dampingRatio * mass / frequencyResponse
        
        self.init(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: .zero)
    }
}

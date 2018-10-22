//
//  PulleyPosition.swift
//  Pulley
//
//  Created by Kyle Burkholder on 8/1/18.
//  Copyright © 2018 52inc. All rights reserved.
//

/**
 Represents a Pulley drawer position.
 
 - collapsed:         When the drawer is in its smallest form, at the bottom of the screen.
 - partiallyRevealed: When the drawer is partially revealed.
 - revealed:          Added by KB. Gives me a third open option.
 - open:              When the drawer is fully open.
 - closed:            When the drawer is off-screen at the bottom of the view. Note: Users cannot close or reopen the drawer on their own. You must set this programatically
 */
@objc public class PulleyPosition: NSObject {
    
    public static let closed = PulleyPosition(rawValue: 1)
    public static let collapsed = PulleyPosition(rawValue: 2)
    public static let standard = PulleyPosition(rawValue: 3)
    public static let partiallyRevealed = PulleyPosition(rawValue: 4)
    public static let revealed = PulleyPosition(rawValue: 5)
    public static let open = PulleyPosition(rawValue: 6)
    
    
    
    public static let all: [PulleyPosition] = [
        .collapsed,
        .standard,
        .partiallyRevealed,
        .revealed,
        .open,
        .closed
    ]
    
    let rawValue: Int
    
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static func positionFor(string: String?) -> PulleyPosition {
        
        guard let positionString = string?.lowercased() else {
            
            return .collapsed
        }
        
        switch positionString {
            
        case "collapsed":
            return .collapsed
            
        case "standard":
            return .standard
            
        case "partiallyRevealed":
            return .partiallyRevealed
            
        case "revealed":
            return .revealed
            
        case "open":
            return .open
            
        case "closed":
            return .closed
            
        default:
            print("PulleyViewController: Position for string '\(positionString)' not found. Available values are: collapsed, partiallyRevealed, open, and closed. Defaulting to collapsed.")
            return .collapsed
        }
    }
}

/// Drawer type class that works with the delegation process
@objc public class DrawerType: NSObject
{
    public static let top = DrawerType(rawValue: 0)
    public static let bottom = DrawerType(rawValue: 1)
    
    let rawValue: Int
    
    init(rawValue:Int)
    {
        self.rawValue = rawValue
    }
}

/// Represents the current display mode for Pulley
///
/// - leftSide: Show as a floating panel on the left
/// - bottomDrawer: Show as a bottom drawer
/// - automatic: Determine it based on device / orientation / size class (like Maps.app)
public enum PulleyDisplayMode {
    case leftSide
    case drawer
    case automatic
}

/// Represents the 'snap' mode for Pulley. The default is 'nearest position'. You can use 'nearestPositionUnlessExceeded' to make the drawer feel lighter or heavier.
///
/// - nearestPosition: Snap to the nearest position when scroll stops
/// - nearestPositionUnlessExceeded: Snap to the nearest position when scroll stops, unless the distance is greater than 'threshold', in which case advance to the next drawer position.
public enum PulleySnapMode {
    case nearestPosition
    case nearestPositionUnlessExceeded(threshold: CGFloat)
}


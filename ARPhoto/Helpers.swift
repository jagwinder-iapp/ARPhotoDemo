//
//  Extensions.swift
//  ARPhotoDemo
//
//  Created by Geetam Singh on 24/12/25.
//

import SwiftUI
import UIKit

class Helper{
    static func topViewController(controller: UIViewController? = UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).first?.windows.first(where: {$0.isKeyWindow})?.rootViewController) -> UIViewController? {
        
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}

extension UIView{
    func screenshot() -> UIImage {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { ctx in
                drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
        }
}

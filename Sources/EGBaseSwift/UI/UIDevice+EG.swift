//
//  Device+EG.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/24.
//

import UIKit

extension UIDevice {
    var isIPad: Bool {
        return self.userInterfaceIdiom == .pad
    }

    var benchmark: CGSize {
        // 9.7 inch iPad
        isIPad ? .init(width: 768, height: 1024)
        // 4.7 inch iPhone
        : .init(width: 375, height: 667)
    }
}

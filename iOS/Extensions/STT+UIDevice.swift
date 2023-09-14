//
//  STT+UIDevice.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-29.
//

import UIKit

extension UIDevice {
    var hasNotch: Bool {
        let bottom = UIApplication.shared.windows[0].safeAreaInsets.bottom
        return bottom > 0
    }
}

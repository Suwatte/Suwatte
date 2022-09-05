//
//  STT+Double.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-06.
//

import Foundation

extension Double {
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }
}

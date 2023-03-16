//
//  DSK+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import AnyCodable
import Foundation

extension DaisukeEngine.Structs {
    enum PreferenceType: Int, Codable {
        case select, multiSelect, stepper, toggle, textfield, button
    }

    struct SelectOption: Parsable, Hashable {
        var label: String
        var value: String
    }

    struct PreferenceGroup: Parsable, Hashable {
        var id: String
        var header: String?
        var footer: String?
        var children: [Preference]
    }

    struct Preference: Parsable, Hashable {
        var key: String
        var label: String
        var type: PreferenceType
        var options: [SelectOption]?

        var value: AnyCodable
        // Stepper
        var maxValue: Int?
        var minValue: Int?

        // MultiSelect
        var minSelectionCount: Int?
        var maxSelectionCount: Int?

        // Button
        var subtitle: String?
        var isDestructive: Bool?
        var systemImage: String?

        var minStepper: Int {
            minValue ?? 1
        }

        var maxStepper: Int {
            maxValue ?? 100
        }

        var minSelect: Int {
            minSelectionCount ?? 1
        }

        var maxSelect: Int {
            maxSelectionCount ?? 10
        }
    }
}

//
//  DSK+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation

extension DaisukeEngine.Structs {
    enum PreferenceType: Int, Decodable {
        case select, multiSelect, stepper, toggle, textfield
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
        var defaultValue: String
        var options: [SelectOption]?
    }
}

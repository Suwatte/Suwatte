//
//  DSK+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation
import AnyCodable


extension DSKCommon {
    struct IOption : Parsable, Hashable, Identifiable {
        let key: String
        let label: String
        
        var id: Int {
            hashValue
        }
    }
    
    enum UIComponentType : String, Parsable {
        case picker, stepper, multipicker, textfield, button, toggle , datepicker
    }
    
    struct UISection<T: Parsable> : Parsable, Hashable where T : Hashable {
        let header: String?
        let footer: String?
        let children: [T]
    }
    
    struct TrackForm: Parsable, Hashable {
        let sections: [UISection<TrackFormComponent>]
    }
    
   
    struct TrackFormComponent: Parsable, Hashable {
        let key: String
        let label: String
        
        let currentValue: AnyCodable?
        
        // When nil the component is required to have a current value
        let notRequired: AnyCodable?
        
        let upperBound: Double?
        let lowerBound: Double?
        let allowDecimal: AnyCodable?
        let step: Double?
        
        let options: [IOption]?
        let maxSelections: Int?
        let minSelections: Int?
        
        let type: UIComponentType
        
        var faulty: Bool {
            currentValue == nil && !isRemovable
        }
        
        var isRemovable: Bool {
            notRequired != nil || notRequired?.value != nil
        }
        
        var isDecimalAllowed: Bool {
            notRequired != nil || notRequired?.value != nil
        }
        
    }
}

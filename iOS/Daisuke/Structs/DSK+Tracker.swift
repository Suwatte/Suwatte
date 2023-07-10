//
//  DSK+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation
import AnyCodable


// MARK: - Core

extension DSKCommon {
    
    enum TrackStatus: String, Codable {
        case CURRENT, PLANNING, COMPLETED, PAUSED, DROPPED, REREADING
    }
    
    struct TrackForm: Parsable, Hashable {
        let sections: [UISection<TrackFormComponent>]
    }
    
    struct TrackItem: Parsable, Hashable, Identifiable {
        let id: String
        let title: String
        let thumbnail: String
        let entry: TrackEntry?
    }
    
    struct TrackProgress: Parsable, Hashable {
        let lastReadChapter: Double
        let lastReadVolume: Double?
        let maxAvailableChapter: Double?
    }
    
    struct TrackEntry: Parsable, Hashable {
        let status: TrackStatus
        let progress: TrackProgress
    }
}


// MARK: - Form
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


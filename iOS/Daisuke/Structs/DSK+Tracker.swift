//
//  DSK+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation
import AnyCodable
import SwiftUI

// MARK: - Core

extension DSKCommon {
    
    enum TrackStatus: String, Codable, CaseIterable {
        case CURRENT, PLANNING, COMPLETED, PAUSED, DROPPED, REPEATING
    }
    
    struct TrackForm: Parsable, Hashable {
        let sections: [UISection<TrackFormComponent>]
    }
    
    struct TrackItem: Parsable, Hashable, Identifiable {
        let id: String
        let title: String
        let cover: String
        let webUrl: String
        var entry: TrackEntry?
        let info: [String]?
    }
    
    struct TrackProgress: Parsable, Hashable {
        var lastReadChapter: Double
        var lastReadVolume: Double?
        let maxAvailableChapter: Double?
    }
    
    struct TrackProgressUpdate: Parsable, Hashable {
        let chapter: Double?
        let volume: Double?
    }
    
    struct TrackEntry: Parsable, Hashable {
        var status: TrackStatus
        var progress: TrackProgress
    }
}

extension DSKCommon.TrackStatus {
    var description : String {
        switch self {
        case .CURRENT:
            return "Reading"
        case .PLANNING:
            return "Planning"
        case .COMPLETED:
            return "Completed"
        case .DROPPED:
            return "Dropped"
        case .PAUSED:
            return "Paused"
        case .REPEATING:
            return "Rereading"
        }
    }
    
    var systemImage: String {
        switch self {
        case .CURRENT:
            return "play.circle"
        case .PLANNING:
            return "square.stack.3d.up"
        case .COMPLETED:
            return "checkmark.circle"
        case .DROPPED:
            return "trash.circle"
        case .PAUSED:
            return "pause.circle"
        case .REPEATING:
            return "repeat.circle"
        }
    }

    var color: Color {
        switch self {
        case .CURRENT:
            return .blue
        case .PLANNING:
            return .yellow
        case .COMPLETED:
            return .green
        case .DROPPED:
            return .red
        case .PAUSED:
            return .gray
        case .REPEATING:
            return .cyan
        }
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


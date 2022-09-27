//
//  DSK+Actions.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-26.
//

import Foundation



extension DSKCommon {
    
    struct Action: DaisukeInterface {
        var key: String
        var title: String
        var subtitle: String?
        var systemImage: String?
        var isDestructive: Bool?
        
        
        var destructive: Bool {
            isDestructive ?? false
        }
        var id: String {
            key
        }
    }
    
    
    struct ActionGroup : DaisukeInterface {
        var id: String
        var header: String?
        var footer: String?
        var children: [Action]
    }
}

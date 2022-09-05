//
//  Queue.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-07.
//

import Foundation

// Reference : https://benoitpasquier.com/data-structure-implement-queue-swift/
struct Queue<T> {
    private var elements: [T] = []

    mutating func enqueue(_ value: T) {
        elements.append(value)
    }

    mutating func dequeue() -> T? {
        guard !elements.isEmpty else {
            return nil
        }
        return elements.removeFirst()
    }

    var head: T? {
        return elements.first
    }

    var tail: T? {
        return elements.last
    }
}

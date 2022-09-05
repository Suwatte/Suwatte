//
//  STT+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-15.
//

import Foundation

extension Array {
    // Reference: https://stackoverflow.com/a/25330930
    // Safely lookup an index that might be out of bounds,
    // returning nil if it does not exist
    func get(index: Int) -> Element? {
        if index >= 0, index < count {
            return self[index]
        } else {
            return nil
        }
    }
}

// Reference: https://stackoverflow.com/a/62563773
extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

// Reference: https://www.swiftbysundell.com/articles/async-and-concurrent-forEach-and-map/
extension Sequence {
    @discardableResult func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

extension Array {
    func map<Value>(_ keyPath: KeyPath<Element, Value>) -> [Value] {
        return map { $0[keyPath: keyPath] }
    }

    func distinct() -> [Element] where Element: Hashable {
        Array(Set(self))
    }
}

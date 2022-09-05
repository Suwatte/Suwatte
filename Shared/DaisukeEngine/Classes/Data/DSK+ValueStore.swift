//
//  DSK+Data.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Foundation
import JavaScriptCore

@objc protocol DaisukeValueStoreProtocol: JSExport, JSObjectProtocol {
    func get(key: String) throws -> String
    func set(key: String, value: String) throws

    @objc(get:)
    func _get(key: JSValue) -> JSValue

    @objc(set::)
    func _set(key: JSValue, value: JSValue) -> JSValue
}

extension DaisukeEngine {
    @objc class ValueStore: JSObject, DaisukeValueStoreProtocol {
        func getContainerId() throws -> String {
            guard let runner = this?.value.context.daisukeRunner() else {
                throw Errors.RunnerNotFoundOnContainedObject
            }

            guard let id = runner.forProperty("info")?.forProperty("id")?.toString() else {
                throw Errors.UnableToFetchRunnerIDInContainedObject
            }

            return id
        }

        func get(key: String) throws -> String {
            let value = DataManager.shared.getStoreValue(for: try getContainerId(), key: key)

            guard let value = value else {
                throw Errors.ValueStoreErrorValueNotFound
            }

            return value
        }

        func set(key: String, value: String) throws {
            DataManager.shared.setStoreValue(for: try getContainerId(), key: key, value: value)
        }

        func _get(key: JSValue) -> JSValue {
            return .init(newPromiseIn: key.context) { resolve, reject in
                let context = key.context
                guard let key = key.toString() else {
                    reject?.call(withArguments: [Errors.ValueStoreErrorKeyIsNotString])
                    return
                }
                do {
                    let value = try self.get(key: key)
                    resolve?.call(withArguments: [value])
                } catch Errors.ValueStoreErrorValueNotFound {
                    resolve?.call(withArguments: [JSValue(nullIn: context) as Any])
                } catch {
                    reject?.call(withArguments: [error])
                }
            }
        }

        func _set(key: JSValue, value: JSValue) -> JSValue {
            return .init(newPromiseIn: key.context) { resolve, reject in
                guard let key = key.toString(), let value = value.toString() else {
                    reject?.call(withArguments: [Errors.ValueStoreErrorKeyValuePairInvalid])
                    return
                }
                do {
                    try self.set(key: key, value: value)
                    resolve?.call(withArguments: nil)
                } catch {
                    reject?.call(withArguments: [error])
                }
            }
        }
    }
}

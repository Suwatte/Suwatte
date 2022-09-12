//
//  DSK+Error.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Foundation
import JavaScriptCore

extension DaisukeEngine {
    enum Errors: Error {
        case MethodNotImplemented // PlaceHolder Error
        case RunnerClassInitFailed
        case RunnerInfoInitFailed
        case RunnerNotFoundOnContainedObject
        case UnableToFetchRunnerIDInContainedObject

        case ValueStoreErrorValueNotFound
        case ValueStoreErrorKeyIsNotString
        case ValueStoreErrorKeyValuePairInvalid

        case NetworkErrorFailedToConvertRequestObject
        case NetworkErrorInvalidRequestURL
        case NamedError(name: String, message: String)
        case MethodNotFound(name: String)
        case ObjectConversionFailed
        case InvalidJSONObject
        case RealmThawFailure
        case NetworkErrorCloudflareProtected
        case LocalFilePathNotFound
//        case ConversionFailed()

        static func nativeError(for errorValue: JSValue) -> Error {
            if let error = errorValue.toObject() as? Error {
                return error
            }
            let errorName = errorValue.objectForKeyedSubscript("name")?.toString() ?? "UnknownError"
            let errorMessage = errorValue.objectForKeyedSubscript("message")?.toString() ?? errorValue.toString() ?? "Unknown message"
            let error = DaisukeEngine.Errors.NamedError(name: errorName, message: errorMessage)
            return error
        }
    }
}

extension DaisukeEngine.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .MethodNotImplemented: return .init("Swift Method Not Implemented")
        case .RunnerClassInitFailed: return .init("Runner Class Failed to Initialize")
        case .RunnerInfoInitFailed: return .init("Runner Class Info Object Could Not Be Parsed")
        case .RunnerNotFoundOnContainedObject: return .init("Runner Class Not Found in Contained context")
        case .UnableToFetchRunnerIDInContainedObject: return .init("Unable to Fetch Runner Class ID in contained context")

        case .ValueStoreErrorValueNotFound: return .init("[Value Store] NF")
        case .ValueStoreErrorKeyIsNotString: return .init("[Value Store] Key is not String")
        case .ValueStoreErrorKeyValuePairInvalid: return .init("[Value Store] Value is not valid")

        case .NetworkErrorFailedToConvertRequestObject: return .init("Request Object Is not valid")
        case .NetworkErrorInvalidRequestURL: return .init("Reqeust URL is invalid")
        case let .NamedError(name, message): return .init("[\(name)] \(message)")
        case let .MethodNotFound(name): return .init("JS Method not found for name: \(name)")
        case .ObjectConversionFailed: return .init("Object Could not be converted to [String:Any]")
        case .InvalidJSONObject: return .init("Object is not valid JSON")
        case .RealmThawFailure: return .init("Failed To Thaw Realm Object")
        case .NetworkErrorCloudflareProtected: return .init("Cloudflare Protected DataPoint")
        case .LocalFilePathNotFound: return .init("Path To File is Null")
        }
    }
}

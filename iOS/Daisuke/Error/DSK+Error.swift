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
        case FailedToParseRunnerIntents
        case FailedToParseRunnerConfig
        case InvalidRunnerEnvironment
        case RunnerExecutableNotFound(id: String)

        case RunnerNotFoundOnContainedObject
        case UnableToFetchRunnerIDInContainedObject

        case ValueStoreErrorValueNotFound
        case ValueStoreErrorKeyIsNotString
        case ValueStoreErrorKeyValuePairInvalid

        case NetworkErrorFailedToConvertRequestObject
        case NetworkErrorInvalidRequestURL
        case NamedError(name: String, message: String)
        case NetworkError(message: String, response: String)
        case MethodNotFound(name: String)
        case ObjectConversionFailed
        case InvalidJSONObject
        case RealmThawFailure
        case NetworkErrorCloudflareProtected
        case LocalFilePathNotFound
        case Cloudflare(resolutionURL: String?)

        static func nativeError(for errorValue: JSValue) -> Error {
            if let error = errorValue.toObject() as? Error {
                return error
            }

            var name = "JS Error"
            var message = "\(errorValue)"
            if let value = errorValue.objectForKeyedSubscript("name"), !value.isUndefined, !value.isNull {
                name = value.toString() ?? name
            }
            if let value = errorValue.objectForKeyedSubscript("message"), !value.isUndefined, !value.isNull {
                message = value.toString() ?? message
            }

            if name == "NetworkError" {
                var response = ""
                if let res = errorValue.objectForKeyedSubscript("res"), let val = try? DSKCommon.Response(value: res).data {
                    response = val
                }
                return DSK.Errors.NetworkError(message: message, response: response)
            }

            if name == "CloudflareError" {
                var resolutionURL: String?
                
                if let value = errorValue.objectForKeyedSubscript("resolutionURL"), !value.isUndefined, !value.isNull {
                    resolutionURL = value.toString()
                }
                
                return DSK.Errors.Cloudflare(resolutionURL: resolutionURL)
            }

            return DaisukeEngine.Errors.NamedError(name: name, message: message)
        }

        static func nativeWKError(for error: AnyObject) -> Error {

            var name = "JS Error"
            var message = error["message"] as? String ?? ""
            if let value = error["name"] as? String, !value.isEmpty {
                name = value
            }

            if name == "NetworkError" {
                var response = ""
                if let res = error["res"] as? [String: Any], let val = try? DSKCommon.Response(dict: res).data {
                    response = val
                }
                return DSK.Errors.NetworkError(message: message, response: response)
            }

            if name == "CloudflareError" {
                var resolutionURL: String?

                if let value = error["resolutionURL"] as? String, !value.isEmpty {
                    resolutionURL = value
                }

                return DSK.Errors.Cloudflare(resolutionURL: resolutionURL)
            }

            return DaisukeEngine.Errors.NamedError(name: name, message: message)
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
        case .FailedToParseRunnerIntents: return .init("Failed to Parse Runner Intents")
        case .FailedToParseRunnerConfig: return .init("Failed to Parse Runner Config")
        case .InvalidRunnerEnvironment: return .init("The Requested Runner is not available in the evironment specified")
        case let .RunnerExecutableNotFound(id): return .init("Runner Script was not found\n[\(id)]")
        case let .NetworkError(message, _): return .init("[Network Error] \(message)")
        case .ValueStoreErrorValueNotFound: return .init("[Value Store] NF")
        case .ValueStoreErrorKeyIsNotString: return .init("[Value Store] Key is not String")
        case .ValueStoreErrorKeyValuePairInvalid: return .init("[Value Store] Value is not valid")
        case .Cloudflare: return .init("Cloudflare Protected Resource")

        case .NetworkErrorFailedToConvertRequestObject: return .init("Request Object Is not valid")
        case .NetworkErrorInvalidRequestURL: return .init("Request URL is invalid")
        case let .NamedError(name, message): return .init("[\(name)] \(message)")
        case let .MethodNotFound(name): return .init("JS Method not found for name: \(name)")
        case .ObjectConversionFailed: return .init("Object Could not be converted to [String:Any]")
        case .InvalidJSONObject: return .init("Object is not valid JSON")
        case .RealmThawFailure: return .init("Failed To Thaw Realm Object")
        case .NetworkErrorCloudflareProtected: return .init("Cloudflare Protected Resource")
        case .LocalFilePathNotFound: return .init("Path To File is Null")
        }
    }
}

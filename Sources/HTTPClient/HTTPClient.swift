//
//  HTTPClient.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

import Foundation

public typealias HTTPHeader = [String: String]

public enum PropertyType {
    case baseUrl(String)
    case path(String)
    case method(MethodType)
    case timeout(TimeInterval)
    case header(HTTPHeader)
    case retry(Int)
    case dispatcher(DispatcherIdentifier)
    case custom(key: String, value: Any)
}

public enum InputType {
    case encodable
    case dict
    case key(String)
    case tuple
}

public enum OutputType {
    case decodable
    case raw
    case key(String)
    case tuple
}

public enum MethodType {
    case get
    case post
    case put
    case delete
    case patch
}

public actor HTTPClient {
    public static let shared: HTTPClient = .init()

    private init() {}

    private var dispatchers: [Dispatcher] = []

    public func register(dispatcher: Dispatcher) {
        dispatchers.append(dispatcher)
    }
}

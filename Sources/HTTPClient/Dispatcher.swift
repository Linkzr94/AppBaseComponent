//
//  Dispatcher.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

import Dispatch
import Foundation

public typealias DispatcherIdentifier = String

public final class Dispatcher: Sendable {
    let identifier: String
    let baseUrl: String?
    let engine: Engine
    
    init(identifier: String, baseUrl: String? = nil, engine: Engine) {
        self.identifier = identifier
        self.baseUrl = baseUrl
        self.engine = engine
    }
    
    func dispatch<Input, Output>(action: Action<Input, Output>) async -> Result<Output, Error> {
        .failure(NSError())
    }
    
    static let `default`: Dispatcher = .init(identifier: "com.dispatcher.alamofire", engine: AFEngine())
}

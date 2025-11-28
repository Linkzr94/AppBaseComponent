//
//  Dispatcher.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

import Dispatch

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
    
    func dispatch<Input, Output>(action: Action<Input, Output>, completion: ((Result<Output, Error>) -> Void)?) {
        
    }
}

public struct DispatcherBuilder {
    private let identifier: DispatcherIdentifier
    
    init(identifier: DispatcherIdentifier) {
        self.identifier = identifier
    }
    
    private var baseUrl: String?
    private var engine: Engine?
    private var queue: DispatchQueue?
}

public extension DispatcherBuilder {
    mutating func set(baseUrl: String) -> Self {
        self.baseUrl = baseUrl
        return self
    }
    
    mutating func set(engine: Engine) -> Self {
        self.engine = engine
        return self
    }
    
    mutating func set(queue: DispatchQueue) -> Self {
        self.queue = queue
        return self
    }
    
    func build() {
        let dispatcher = Dispatcher(identifier: identifier, baseUrl: baseUrl, engine: engine ?? SystemEngine())
        Task.detached {
            await HTTPClient.shared.register(dispatcher: dispatcher)
        }
    }
}

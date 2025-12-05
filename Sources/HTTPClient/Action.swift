//
//  Action.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

@propertyWrapper
public final class GET<Input: Sendable, Output: Sendable>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.get))
        return self.action()
    }
}

@propertyWrapper
public final class POST<Input: Sendable, Output: Sendable>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.post))
        return self.action()
    }
}

@propertyWrapper
public final class PUT<Input: Sendable, Output: Sendable>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.put))
        return self.action()
    }
}

@propertyWrapper
public final class DELETE<Input: Sendable, Output: Sendable>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.delete))
        return self.action()
    }
}

@propertyWrapper
public final class PATCH<Input: Sendable, Output: Sendable>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.patch))
        return self.action()
    }
}

public class ActionAnnotation<Input: Sendable, Output: Sendable>: Annontation {
    func action() -> Action<Input, Output> {
        Action(annotation: self)
    }
}

public actor Action<Input: Sendable, Output: Sendable> {
    let properties: [PropertyType]
    let inputType: InputType
    let outputType: OutputType
    
    private(set) var input: Input!
    
    init(annotation: ActionAnnotation<Input, Output>) {
        self.inputType = annotation.inputType
        self.outputType = annotation.outputType
        self.properties = annotation.properties
    }
    
    func enqueue() async -> Result<Output, Error> {
        await self.dispatcher().dispatch(action: self)
    }
    
    private func dispatcher() async -> Dispatcher {
        var identifier: String?
        for property in properties {
            if case .dispatcher(let dispatcherIdentifier) = property {
                identifier = dispatcherIdentifier
            }
        }
        return await HTTPClient.shared.dispatcher(by: identifier)
    }
}

public extension Action {
    func request(_ input: Input, completion: ((_ result: Result<Output, Error>) -> Void)? = nil) {
        Task {
            await self.request(input)
        }
    }
    
    func request(_ completion: ((_ result: Result<Output, Error>) -> Void)? = nil) where Input == EmptyInput {
        request(.empty, completion: completion)
    }
    
    func request() async -> Result<Output, Error> where Input == EmptyInput {
        await self.request(.empty)
    }
    
    func request(_ input: Input) async -> Result<Output, Error> {
        self.input = input
        return await self.enqueue()
    }
}

//
//  Action.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

@propertyWrapper
public final class GET<Input, Output>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.get))
        return self.action()
    }
}

@propertyWrapper
public final class POST<Input, Output>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.post))
        return self.action()
    }
}

@propertyWrapper
public final class PUT<Input, Output>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.put))
        return self.action()
    }
}

@propertyWrapper
public final class DELETE<Input, Output>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.delete))
        return self.action()
    }
}

@propertyWrapper
public final class PATCH<Input, Output>: ActionAnnotation<Input, Output> {
    public var wrappedValue: Action<Input, Output> {
        self.properties.append(.method(.patch))
        return self.action()
    }
}

public class ActionAnnotation<Request, Response>: Annontation {
    func action() -> Action<Request, Response> {
        Action(annotation: self)
    }
}

public class Action<Input, Output> {
    let properties: [PropertyType]
    let inputType: InputType
    let outputType: OutputType
    
    init(annotation: ActionAnnotation<Input, Output>) {
        self.inputType = annotation.inputType
        self.outputType = annotation.outputType
        self.properties = annotation.properties
    }
    
    func request() {
        
    }
    
    func enqueue(_ completion: ((Result<Output, Error>) -> Void)?) {
        
    }
}

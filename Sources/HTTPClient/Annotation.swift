//
//  Annotation.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/28.
//

public class Annontation {
    var properties: [PropertyType]
    let inputType: InputType
    let outputType: OutputType
    
    init(properties: [PropertyType],
         inputType: InputType = .encodable,
         outputType: OutputType = .decodable) {
        self.inputType = inputType
        self.outputType = outputType
        self.properties = properties
    }
}

public extension Annontation {
    convenience init(_ path: String,
                     inputType: InputType = .encodable,
                     outputType: OutputType = .decodable) {
        self.init(.path(path), inputType: inputType, outputType: outputType)
    }
    
    convenience init(_ properties: PropertyType...,
                     inputType: InputType = .encodable,
                     outputType: OutputType = .decodable) {
        self.init(properties: properties, inputType: inputType, outputType: outputType)
    }
    
    convenience init(_ path: String,
                     _ properties: PropertyType...,
                     inputType: InputType = .encodable,
                     outputType: OutputType = .decodable) {
        self.init(properties: properties + [.path(path)], inputType: inputType, outputType: outputType)
    }
}

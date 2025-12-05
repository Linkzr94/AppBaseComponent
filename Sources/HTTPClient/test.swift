//
//  test.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/12/4.
//

class NetTest {
    
    @GET("", .baseUrl("https://www.baidu.comm"), .header(["xxx":"yyy"]))
    var testApi: Action<TestInput, TestOutput>
    
    func test() {
//        Task {
//            let input: TestInput = .init()
//            await testApi.request(input) { result in
//                
//            }
//        }
    }
}

struct TestInput {
    
}

struct TestOutput {
    
}

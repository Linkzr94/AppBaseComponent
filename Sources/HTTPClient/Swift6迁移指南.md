# Vega Swift 6 迁移指南

> Swift 6 引入了严格的并发检查、数据隔离和 Sendable 协议，本指南详细说明如何将 Vega 迁移到 Swift 6

---

## 目录

1. [Swift 6 核心变化](#swift-6-核心变化)
2. [Vega 当前问题分析](#vega-当前问题分析)
3. [迁移方案](#迁移方案)
4. [完整实现示例](#完整实现示例)

---

## Swift 6 核心变化

### 1. 严格并发检查

Swift 6 默认启用完整的并发安全检查，主要包括：

- **数据隔离（Data Isolation）**：确保可变状态不会跨并发域共享
- **Sendable 协议**：标记可以安全跨并发域传递的类型
- **Actor 隔离**：强制 actor 的属性只能在 actor 内部访问
- **全局可变状态保护**：静态可变变量必须被保护

### 2. 主要新特性

- ✅ **完整的数据竞争安全**
- ✅ **@Sendable 闭包**
- ✅ **Sendable 协议约束**
- ✅ **Actor 隔离检查**
- ✅ **nonisolated(unsafe) 关键字**
- ✅ **全局 actor（@MainActor）**

---

## Vega 当前问题分析

### 问题 1：静态可变状态（高危）

**位置**：`Vega.swift:11`

```swift
// ❌ Swift 6 错误：静态可变状态没有保护
public struct Vega {
    private static var providerList: [VegaProvider] = []
}
```

**问题**：
- 静态可变数组在多线程环境下不安全
- Swift 6 会报错：`Static property 'providerList' is not concurrency-safe`

---

### 问题 2：非 Sendable 的协议和类型

**位置**：`VegaProvider.swift:12`

```swift
// ❌ 协议没有标记为 Sendable
internal protocol VegaProvider {
    var queue: DispatchQueue { get }
    func enqueue<Input, Output>(action: ActionModel<Input, Output>, ...)
}
```

**问题**：
- `VegaProvider` 需要跨并发域传递，但未标记 Sendable
- `ActionModel` 类是引用类型，包含可变状态

---

### 问题 3：闭包并发安全

**位置**：`ActionModel.swift:48`

```swift
// ❌ 闭包捕获 self，可能导致数据竞争
public dynamic func request(_ input: Input, completion: ((Result<Output, Error>) -> Void)?) {
    self._input = input
    self.enqueue(completion)
}
```

**问题**：
- 闭包可能在不同线程执行
- `_input` 是可变属性，需要保护

---

### 问题 4：DispatchQueue 使用

**位置**：`VegaProvider.swift:33`

```swift
// ⚠️ DispatchQueue 在 Swift 6 中需要特殊处理
var queue: DispatchQueue = .main
```

**问题**：
- Swift 6 推荐使用 Actor 而不是 DispatchQueue
- DispatchQueue 不是 Sendable

---

## 迁移方案

### 方案 1：使用 Actor 重构核心组件（推荐）

#### 1.1 将 VegaProviderManager 改为 Actor

```swift
/// Swift 6: 使用 Actor 确保线程安全
public actor VegaProviderManager {
    public static let shared = VegaProviderManager()
    
    private var providers: [VegaProviderIdentifier: any VegaProvider] = [:]
    private let defaultIdentifier: VegaProviderIdentifier = "__default__"
    
    private init() {}
    
    // Actor 方法自动在隔离环境中执行
    public func register(_ provider: any VegaProvider, replaceIfExists: Bool = false) throws {
        if providers[provider.identifier] != nil && !replaceIfExists {
            throw NetworkError.invalidConfiguration(
                reason: "Provider '\(provider.identifier)' 已存在"
            )
        }
        providers[provider.identifier] = provider
        
        if providers.count == 1 {
            providers[defaultIdentifier] = provider
        }
    }
    
    public func unregister(identifier: VegaProviderIdentifier) {
        providers.removeValue(forKey: identifier)
    }
    
    public func getProvider(by identifier: VegaProviderIdentifier?) throws -> any VegaProvider {
        let targetIdentifier = identifier ?? defaultIdentifier
        
        guard let provider = providers[targetIdentifier] else {
            throw NetworkError.providerNotFound(identifier: targetIdentifier)
        }
        
        return provider
    }
    
    public var registeredIdentifiers: [VegaProviderIdentifier] {
        Array(providers.keys).filter { $0 != defaultIdentifier }
    }
}
```

**优势**：
- ✅ 自动保证线程安全
- ✅ 符合 Swift 6 并发模型
- ✅ 无需手动加锁

---

#### 1.2 标记 Sendable 协议

```swift
/// Swift 6: 所有跨并发域传递的协议必须标记 Sendable
public protocol VegaProvider: Sendable {
    var identifier: VegaProviderIdentifier { get }
    var baseUrl: String? { get }
    var httpClient: any HTTPClient { get }
    var converter: any DataConverter { get }
    
    // 使用 nonisolated 允许从任何上下文调用
    nonisolated func enqueue<Input, Output>(
        action: ActionModel<Input, Output>,
        completion: (@Sendable (Result<Output, Error>) -> Void)?
    ) where Input: Sendable, Output: Sendable
}

// HTTPClient 也需要标记 Sendable
public protocol HTTPClient: Sendable {
    func performRequest<Input, Output>(
        action: ActionModel<Input, Output>,
        requestData: RequestData,
        completion: @Sendable @escaping (ResponseData) -> Void
    ) -> (any Cancellable)? where Input: Sendable, Output: Sendable
}

// DataConverter 需要 Sendable
public protocol DataConverter: Sendable {
    func convert<Input: Encodable & Sendable>(
        _ input: Input,
        inputType: ActionInput
    ) throws -> Data
    
    func convert<Output: Decodable & Sendable>(
        _ data: Data,
        outputType: ActionOutput
    ) throws -> Output
}
```

---

#### 1.3 重构 ActionModel 为线程安全

**方案 A：使用 Actor（推荐）**

```swift
/// Swift 6: ActionModel 作为 Actor 确保状态安全
public actor ActionModel<Input: Sendable, Output: Sendable> {
    internal let property: ActionPropertyModel
    public let inputType: ActionInput
    public let outputType: ActionOutput
    
    private var requestInterceptorList: [any ActionRequestInterceptor] = []
    private var responseInterceptorList: [any ActionResponseInterceptor] = []
    private var progressHandler: (@Sendable (_ completeCount: Int64, _ totalCount: Int64) -> Void)?
    
    private var _input: Input?
    public var input: Input? { _input }
    
    public init(annotation: ActionAnnotation<Input, Output>) {
        self.property = .init(with: annotation.propertyModel)
        self.inputType = annotation.inputType
        self.outputType = annotation.outputType
    }
    
    // Actor 方法，自动隔离
    public func addRequestInterceptor(_ interceptor: any ActionRequestInterceptor, insertAtHead: Bool = false) {
        if insertAtHead {
            requestInterceptorList.insert(interceptor, at: 0)
        } else {
            requestInterceptorList.append(interceptor)
        }
    }
    
    // 支持 async/await
    public func request(_ input: Input) async throws -> Output {
        self._input = input
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.enqueue { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    // 兼容闭包版本
    public func request(_ input: Input, completion: (@Sendable (Result<Output, Error>) -> Void)?) {
        Task {
            do {
                let result = try await request(input)
                completion?(.success(result))
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    // 设置进度回调
    public func setProgressHandler(_ handler: (@Sendable (_ completeCount: Int64, _ totalCount: Int64) -> Void)?) {
        self.progressHandler = handler
    }
    
    // 更新进度
    public func updateProgress(completeCount: Int64, totalCount: Int64) {
        progressHandler?(completeCount, totalCount)
    }
}

// 为 Empty 输入提供便捷方法
extension ActionModel where Input == Empty {
    public func request() async throws -> Output {
        try await request(.empty)
    }
    
    public func request(completion: (@Sendable (Result<Output, Error>) -> Void)?) {
        request(.empty, completion: completion)
    }
}
```

**方案 B：使用 Sendable 值类型**

```swift
/// Swift 6: 如果不想用 Actor，可以使用不可变的值类型
public struct ActionModel<Input: Sendable, Output: Sendable>: Sendable {
    internal let property: ActionPropertyModel
    public let inputType: ActionInput
    public let outputType: ActionOutput
    
    // 使用不可变属性
    private let configuration: Configuration
    
    struct Configuration: Sendable {
        let requestInterceptors: [any ActionRequestInterceptor & Sendable]
        let responseInterceptors: [any ActionResponseInterceptor & Sendable]
    }
    
    public init(annotation: ActionAnnotation<Input, Output>) {
        self.property = .init(with: annotation.propertyModel)
        self.inputType = annotation.inputType
        self.outputType = annotation.outputType
        self.configuration = Configuration(
            requestInterceptors: [],
            responseInterceptors: []
        )
    }
    
    // 返回新实例而不是修改
    public func withRequestInterceptor(_ interceptor: any ActionRequestInterceptor & Sendable) -> Self {
        var config = configuration
        var interceptors = config.requestInterceptors
        interceptors.append(interceptor)
        
        var copy = self
        copy.configuration = Configuration(
            requestInterceptors: interceptors,
            responseInterceptors: config.responseInterceptors
        )
        return copy
    }
    
    // 主请求方法
    public func request(_ input: Input) async throws -> Output {
        // 实现请求逻辑
        try await performRequest(input)
    }
    
    private func performRequest(_ input: Input) async throws -> Output {
        // 获取 provider
        let provider = try await VegaProviderManager.shared.getProvider(
            by: property.providerIdentifier
        )
        
        // 执行请求
        return try await withCheckedThrowingContinuation { continuation in
            provider.enqueue(action: self) { result in
                continuation.resume(with: result)
            }
        }
    }
}
```

---

#### 1.4 拦截器协议 Sendable 化

```swift
/// Swift 6: 拦截器必须是 Sendable
public protocol ActionRequestInterceptor: Sendable {
    func process<Input: Sendable, Output: Sendable>(
        action: ActionModel<Input, Output>
    ) async throws -> ActionModel<Input, Output>
}

public protocol ActionResponseInterceptor: Sendable {
    func process<Output: Sendable>(
        _ result: Result<Output, Error>
    ) async -> Result<Output, Error>
}

public protocol DataInterceptor: Sendable {
    func processRequest(_ requestData: RequestData) async throws -> RequestData
    func processResponse(_ responseData: ResponseData) async -> ResponseData
}
```

---

#### 1.5 RequestData 和 ResponseData Sendable 化

```swift
/// Swift 6: 数据模型必须是 Sendable
public struct RequestData: Sendable {
    public let url: URL
    public let httpMethod: String
    public let httpHeaders: [String: String]
    public let body: Data?
    public let timeout: TimeInterval?
    
    // 如果需要扩展信息，使用 Sendable 字典
    public let extendInfo: [String: any Sendable]
    
    public init(
        url: URL,
        httpMethod: String,
        httpHeaders: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval? = nil,
        extendInfo: [String: any Sendable] = [:]
    ) {
        self.url = url
        self.httpMethod = httpMethod
        self.httpHeaders = httpHeaders
        self.body = body
        self.timeout = timeout
        self.extendInfo = extendInfo
    }
}

public struct ResponseData: Sendable {
    public let data: Data?
    public let response: HTTPURLResponse?
    public let error: Error?
    
    public init(data: Data? = nil, response: HTTPURLResponse? = nil, error: Error? = nil) {
        self.data = data
        self.response = response
        self.error = error
    }
}
```

---

### 方案 2：使用 @unchecked Sendable（临时方案）

如果暂时无法完全重构，可以使用 `@unchecked Sendable`：

```swift
/// ⚠️ 临时方案：使用 @unchecked Sendable
/// 需要手动确保线程安全
public class ActionModel<Input, Output>: @unchecked Sendable {
    private let lock = NSLock()
    
    private var _input: Input?
    public var input: Input? {
        lock.lock()
        defer { lock.unlock() }
        return _input
    }
    
    public func request(_ input: Input, completion: @escaping @Sendable (Result<Output, Error>) -> Void) {
        lock.lock()
        self._input = input
        lock.unlock()
        
        self.enqueue(completion)
    }
}
```

**注意**：
- ⚠️ 这只是临时方案
- ⚠️ 必须手动确保线程安全
- ✅ 建议最终迁移到 Actor 或不可变值类型

---

### 方案 3：MainActor 隔离（UI 相关）

对于 UI 相关的代码，使用 `@MainActor`：

```swift
/// Swift 6: UI 回调在主线程执行
extension ActionModel {
    @MainActor
    public func requestOnMain(_ input: Input) async throws -> Output {
        try await request(input)
    }
    
    @MainActor
    public func request(_ input: Input, completion: @escaping (Result<Output, Error>) -> Void) {
        Task {
            do {
                let result = try await request(input)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
```

---

## 完整实现示例

### 示例 1：完整的 Actor-based Provider

```swift
public actor DefaultVegaProvider: VegaProvider {
    public let identifier: VegaProviderIdentifier
    public var baseUrl: String?
    public nonisolated let httpClient: any HTTPClient
    public nonisolated let converter: any DataConverter
    
    private var interceptors: [any DataInterceptor] = []
    private var actionRequestInterceptors: [any ActionRequestInterceptor] = []
    private var actionResponseInterceptors: [any ActionResponseInterceptor] = []
    
    public init(
        identifier: VegaProviderIdentifier,
        httpClient: any HTTPClient,
        converter: any DataConverter
    ) {
        self.identifier = identifier
        self.httpClient = httpClient
        self.converter = converter
    }
    
    public func addInterceptor(_ interceptor: any DataInterceptor) {
        interceptors.append(interceptor)
    }
    
    public nonisolated func enqueue<Input: Sendable, Output: Sendable>(
        action: ActionModel<Input, Output>,
        completion: (@Sendable (Result<Output, Error>) -> Void)?
    ) {
        Task {
            do {
                // 执行请求拦截器
                var currentAction = action
                for interceptor in await actionRequestInterceptors {
                    currentAction = try await interceptor.process(action: currentAction)
                }
                
                // 构建请求
                let requestData = try await buildRequest(for: currentAction)
                
                // 执行网络请求
                let responseData = try await performHTTPRequest(requestData)
                
                // 转换响应
                let output: Output = try converter.convert(responseData.data ?? Data(), outputType: currentAction.outputType)
                
                // 执行响应拦截器
                var result: Result<Output, Error> = .success(output)
                for interceptor in await actionResponseInterceptors {
                    result = await interceptor.process(result)
                }
                
                completion?(result)
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    private func buildRequest<Input: Sendable, Output: Sendable>(
        for action: ActionModel<Input, Output>
    ) async throws -> RequestData {
        // 构建请求逻辑
        guard let input = await action.input else {
            throw NetworkError.invalidConfiguration(reason: "Input is nil")
        }
        
        let body = try converter.convert(input, inputType: action.inputType)
        
        let urlString = (baseUrl ?? "") + action.property.path
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }
        
        return RequestData(
            url: url,
            httpMethod: action.property.httpMethod ?? "GET",
            httpHeaders: action.property.headers ?? [:],
            body: body,
            timeout: action.property.timeout
        )
    }
    
    private func performHTTPRequest(_ requestData: RequestData) async throws -> ResponseData {
        try await withCheckedThrowingContinuation { continuation in
            _ = httpClient.performRequest(
                action: ActionModel<Empty, Empty>(annotation: BaseAnnotation("")),
                requestData: requestData
            ) { responseData in
                if let error = responseData.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: responseData)
                }
            }
        }
    }
}
```

---

### 示例 2：Sendable HTTPClient 实现

```swift
public final class DefaultHTTPClient: HTTPClient, Sendable {
    private let session: URLSession
    
    public init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }
    
    public func performRequest<Input: Sendable, Output: Sendable>(
        action: ActionModel<Input, Output>,
        requestData: RequestData,
        completion: @Sendable @escaping (ResponseData) -> Void
    ) -> (any Cancellable)? {
        var request = URLRequest(url: requestData.url)
        request.httpMethod = requestData.httpMethod
        request.httpBody = requestData.body
        
        if let timeout = requestData.timeout {
            request.timeoutInterval = timeout
        }
        
        for (key, value) in requestData.httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            let responseData = ResponseData(
                data: data,
                response: response as? HTTPURLResponse,
                error: error
            )
            completion(responseData)
        }
        
        task.resume()
        
        let cancellable = URLSessionCancellable(task: task)
        return cancellable
    }
}

// Sendable Cancellable 实现
private final class URLSessionCancellable: Cancellable, @unchecked Sendable {
    private let task: URLSessionDataTask
    private let lock = NSLock()
    private var _isCancelled = false
    
    init(task: URLSessionDataTask) {
        self.task = task
    }
    
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !_isCancelled else { return }
        _isCancelled = true
        task.cancel()
    }
}
```

---

## 迁移检查清单

### ✅ 第一阶段：基础迁移

- [ ] 将 `Vega.providerList` 迁移到 Actor
- [ ] 为所有协议添加 `Sendable` 约束
- [ ] 为所有闭包参数添加 `@Sendable` 标记
- [ ] 将可变类改为 Actor 或不可变结构体
- [ ] 添加泛型约束 `where Input: Sendable, Output: Sendable`

### ✅ 第二阶段：并发优化

- [ ] 用 `async/await` 替换回调
- [ ] 实现基于 Actor 的拦截器链
- [ ] 添加 Task 取消支持
- [ ] 实现并发安全的日志系统

### ✅ 第三阶段：完全迁移

- [ ] 移除所有 `@unchecked Sendable`
- [ ] 完全基于 Actor 重构
- [ ] 添加 Swift 6 单元测试
- [ ] 更新文档和示例

---

## 兼容性策略

### 方案：渐进式迁移

```swift
// 1. 保留旧 API 并标记为废弃
@available(*, deprecated, message: "Use async version instead")
public func request(_ input: Input, completion: ((Result<Output, Error>) -> Void)?) {
    Task {
        do {
            let result = try await request(input)
            completion?(.success(result))
        } catch {
            completion?(.failure(error))
        }
    }
}

// 2. 提供新的 Swift 6 API
public func request(_ input: Input) async throws -> Output {
    // 新实现
}
```

---

## 性能优化建议

### 1. 避免过度使用 Actor

```swift
// ❌ 不好：所有属性都在 Actor 中
actor MyActor {
    var config: Config  // 只读配置不需要隔离
    var state: State    // 需要隔离
}

// ✅ 好：分离不可变和可变状态
actor MyActor {
    nonisolated let config: Config  // 不可变，允许并发访问
    var state: State                 // 可变，受保护
}
```

### 2. 使用 nonisolated 优化性能

```swift
public actor ActionModel<Input: Sendable, Output: Sendable> {
    nonisolated public let property: ActionPropertyModel  // 不可变属性
    private var mutableState: State  // 可变状态受保护
}
```

---

## 总结

### Swift 6 迁移核心要点

1. **使用 Actor 替代锁**：Actor 提供自动的线程安全
2. **标记 Sendable**：所有跨并发域的类型都要 Sendable
3. **@Sendable 闭包**：所有异步闭包标记为 @Sendable
4. **async/await 优先**：用 async/await 替代回调
5. **不可变优先**：尽量使用值类型和不可变属性

### 推荐迁移路径

1. **短期**（1-2周）：
   - 添加 Sendable 标记
   - 使用 @unchecked Sendable 临时解决
   - 添加 async/await API

2. **中期**（2-4周）：
   - 重构为 Actor
   - 移除 @unchecked Sendable
   - 完善并发测试

3. **长期**（持续）：
   - 性能优化
   - 完全移除旧 API
   - 文档更新

---

**文档版本**: v1.0  
**更新时间**: 2025-12-05  
**适用于**: Swift 6.0+, Vega 2.0+

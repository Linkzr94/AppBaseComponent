# Vega 重构改进建议

## 📋 目录

1. [核心架构改进](#核心架构改进)
2. [API 设计优化](#api-设计优化)  
3. [功能增强建议](#功能增强建议)
4. [实施优先级](#实施优先级)

---

## 核心架构改进

### 1.1 完善 HTTP 方法支持

**当前问题**：
- 仅支持 GET 和 POST 方法
- 无法满足 RESTful API 的完整需求

**改进方案**：

添加对所有标准 HTTP 方法的支持：
- PUT - 更新资源
- DELETE - 删除资源  
- PATCH - 部分更新
- HEAD - 获取元数据
- OPTIONS - 获取支持的方法

**实现示例**：

```swift
// 方案 A：扩展现有注解
@propertyWrapper
open class PUT<Input, Output>: ActionAnnotation<Input, Output> {
    open var wrappedValue: ActionModel<Input, Output> {
        return self.createDefaultActionModel()
    }
    
    open override func customize() {
        super.customize()
        self.propertyModel.update(properties: [.httpMethod("put")])
    }
}

// 使用
@PUT("api/users/{id}")
static var updateUser: ActionModel<User, User>
```

---

### 1.2 增强错误处理机制

**当前问题**：
- VegaError 过于简单
- 错误分类不够细致
- 缺少可重试错误的标识

**改进方案**：

重新设计错误类型体系：

```swift
public enum NetworkError: Error {
    // 网络层错误
    case networkFailure(underlying: Error)
    case timeout
    case noConnection
    case cancelled
    
    // HTTP 错误
    case httpError(statusCode: Int, data: Data?)
    case invalidResponse
    case invalidURL(String)
    
    // 数据转换错误
    case decodingError(underlying: Error, data: Data?)
    case encodingError(underlying: Error)
    case typeMismatch(expected: String, actual: Any)
    
    // 业务错误
    case businessError(code: Int, message: String, data: Any?)
    
    // 拦截器错误
    case interceptorError(Error)
    case requestInterrupted(reason: String)
    
    // 配置错误
    case providerNotFound(identifier: String)
    case invalidConfiguration(reason: String)
}

extension NetworkError {
    // 判断是否可重试
    public var isRetryable: Bool {
        switch self {
        case .networkFailure, .timeout, .noConnection:
            return true
        case .httpError(let statusCode, _):
            return (500...599).contains(statusCode) || statusCode == 429
        default:
            return false
        }
    }
    
    // 错误恢复建议
    public var recoverySuggestion: String? {
        switch self {
        case .timeout:
            return "请检查网络连接后重试"
        case .httpError(401, _):
            return "请重新登录"
        case .httpError(429, _):
            return "请求过于频繁，请稍后再试"
        default:
            return nil
        }
    }
}
```

---

### 1.3 改进 Provider 管理

**当前问题**：
- 使用静态数组，无法移除或更新
- fatalError 导致崩溃
- 非线程安全

**改进方案**：

创建线程安全的 Provider 管理器：

```swift
public class VegaProviderManager {
    public static let shared = VegaProviderManager()
    
    private var providers: [VegaProviderIdentifier: VegaProvider] = [:]
    private let lock = NSLock()
    
    // 线程安全的注册
    public func register(_ provider: VegaProvider, replaceIfExists: Bool = false) throws {
        lock.lock()
        defer { lock.unlock() }
        
        if providers[provider.identifier] != nil && !replaceIfExists {
            throw NetworkError.invalidConfiguration(
                reason: "Provider '\(provider.identifier)' 已存在"
            )
        }
        
        providers[provider.identifier] = provider
    }
    
    // 支持移除
    public func unregister(identifier: VegaProviderIdentifier) {
        lock.lock()
        defer { lock.unlock() }
        providers.removeValue(forKey: identifier)
    }
    
    // 返回 Result 而非崩溃
    public func getProvider(by identifier: VegaProviderIdentifier?) -> Result<VegaProvider, NetworkError> {
        lock.lock()
        defer { lock.unlock() }
        
        guard let provider = providers[identifier ?? "__default__"] else {
            return .failure(.providerNotFound(identifier: identifier ?? "default"))
        }
        
        return .success(provider)
    }
}
```

---

## API 设计优化

### 2.1 支持 async/await

**当前问题**：仅支持闭包回调

**改进方案**：

```swift
@available(iOS 13.0, macOS 10.15, *)
extension ActionModel {
    public func request(_ input: Input) async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            self.request(input) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func request() async throws -> Output where Input == Empty {
        return try await request(.empty)
    }
}
```

**使用示例**：

```swift
// 传统方式
getUserProfile.request { result in
    switch result {
    case .success(let profile):
        print(profile)
    case .failure(let error):
        print(error)
    }
}

// async/await 方式
Task {
    do {
        let profile = try await getUserProfile.request()
        print(profile)
    } catch {
        print(error)
    }
}

// 并行多个请求
Task {
    async let profile = getUserProfile.request()
    async let settings = getUserSettings.request()
    async let notifications = getNotifications.request()
    
    let (p, s, n) = try await (profile, settings, notifications)
    updateUI(p, s, n)
}
```

---

### 2.2 支持 Combine

**改进方案**：

```swift
@available(iOS 13.0, macOS 10.15, *)
extension ActionModel {
    public func requestPublisher(_ input: Input) -> AnyPublisher<Output, Error> {
        return Future { promise in
            self.request(input) { result in
                promise(result)
            }
        }
        .eraseToAnyPublisher()
    }
}
```

**使用示例**：

```swift
class ViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadProfile() {
        isLoading = true
        
        getUserProfile.requestPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] profile in
                    self?.profile = profile
                }
            )
            .store(in: &cancellables)
    }
}
```

---

## 功能增强建议

### 3.1 请求取消机制

**当前问题**：无法取消进行中的请求

**改进方案**：

```swift
public protocol Cancellable {
    func cancel()
    var isCancelled: Bool { get }
}

public class CancellableTask: Cancellable {
    private var isCancelledFlag = false
    private var cancelHandler: (() -> Void)?
    
    public var isCancelled: Bool { isCancelledFlag }
    
    public func cancel() {
        guard !isCancelledFlag else { return }
        isCancelledFlag = true
        cancelHandler?()
    }
    
    internal func setCancelHandler(_ handler: @escaping () -> Void) {
        self.cancelHandler = handler
    }
}

// 更新 ActionModel
extension ActionModel {
    @discardableResult
    public func request(_ input: Input, completion: ((Result<Output, Error>) -> Void)?) -> Cancellable {
        let task = CancellableTask()
        
        task.setCancelHandler { [weak self] in
            self?.cancelCurrentRequest()
            completion?(.failure(NetworkError.cancelled))
        }
        
        // 执行请求...
        
        return task
    }
}
```

**使用示例**：

```swift
class ProfileViewController: UIViewController {
    private var currentTask: Cancellable?
    
    func loadProfile() {
        currentTask?.cancel() // 取消之前的请求
        
        currentTask = getUserProfile.request { [weak self] result in
            // 处理结果
        }
    }
    
    deinit {
        currentTask?.cancel()
    }
}
```

---

### 3.2 自动重试策略

**当前问题**：只有简单的 retryCount，没有重试策略

**改进方案**：

```swift
public struct RetryPolicy {
    let maxRetries: Int
    let shouldRetry: (Error, Int) -> Bool
    let backoffStrategy: BackoffStrategy
    
    public enum BackoffStrategy {
        case immediate
        case constant(seconds: TimeInterval)
        case exponential(base: TimeInterval, multiplier: Double = 2.0)
        case custom((Int) -> TimeInterval)
        
        func delay(for attempt: Int) -> TimeInterval {
            switch self {
            case .immediate:
                return 0
            case .constant(let seconds):
                return seconds
            case .exponential(let base, let multiplier):
                return base * pow(multiplier, Double(attempt - 1))
            case .custom(let calculator):
                return calculator(attempt)
            }
        }
    }
    
    // 预定义策略
    public static let `default` = RetryPolicy(
        maxRetries: 3,
        shouldRetry: { error, _ in
            (error as? NetworkError)?.isRetryable ?? false
        },
        backoffStrategy: .exponential(base: 1.0, multiplier: 2.0)
    )
}
```

**使用示例**：

```swift
// 使用预定义策略
@GET("api/data", .retryPolicy(.default))
static var getData: ActionModel<Empty, Data>

// 自定义重试策略
let customPolicy = RetryPolicy(
    maxRetries: 5,
    shouldRetry: { error, attempt in
        if let netError = error as? NetworkError {
            return netError == .timeout || netError == .noConnection
        }
        return false
    },
    backoffStrategy: .exponential(base: 2.0, multiplier: 2.0)
)

@GET("api/important-data", .retryPolicy(customPolicy))
static var getImportantData: ActionModel<Empty, ImportantData>
```

---

### 3.3 日志系统

**改进方案**：

```swift
public enum LogLevel: Int, Comparable {
    case none = 0
    case basic = 1      // URL、方法、状态码
    case headers = 2    // 包含请求/响应头
    case body = 3       // 包含请求/响应体
    case verbose = 4    // 详细日志
}

public class LoggingInterceptor: DataInterceptor {
    public let level: LogLevel
    private let logger: (String) -> Void
    
    public init(level: LogLevel = .basic, logger: @escaping (String) -> Void = { print($0) }) {
        self.level = level
        self.logger = logger
    }
    
    public func process(_ requestData: RequestData) -> RequestData {
        guard level != .none else { return requestData }
        
        var logs: [String] = []
        
        if level >= .basic {
            logs.append("→ \(requestData.httpMethod) \(requestData.url)")
        }
        
        if level >= .headers {
            logs.append("Headers: \(requestData.httpHeaders)")
        }
        
        if level >= .body, let body = requestData.body {
            logs.append("Body: \(String(data: body, encoding: .utf8) ?? "binary")")
        }
        
        logger(logs.joined(separator: "\n"))
        
        return requestData
    }
}
```

**使用示例**：

```swift
#if DEBUG
let logLevel: LogLevel = .verbose
#else
let logLevel: LogLevel = .none
#endif

Vega.builder()
    .addInterceptor(LoggingInterceptor(level: logLevel))
    .build()
```

---

### 3.4 Mock 支持

**改进方案**：

```swift
public struct MockResponse {
    let data: Data?
    let statusCode: Int
    let delay: TimeInterval
    let error: Error?
    
    public static func success<T: Encodable>(_ value: T, delay: TimeInterval = 0) -> MockResponse {
        let data = try? JSONEncoder().encode(value)
        return MockResponse(data: data, statusCode: 200, delay: delay, error: nil)
    }
    
    public static func failure(_ error: Error, delay: TimeInterval = 0) -> MockResponse {
        return MockResponse(data: nil, statusCode: 500, delay: delay, error: error)
    }
}

public class MockProvider: VegaProvider {
    private var mockResponses: [String: MockResponse] = [:]
    
    public func mock(_ path: String, response: MockResponse) {
        mockResponses[path] = response
    }
}
```

**使用示例**：

```swift
#if DEBUG
let mockProvider = MockProvider(identifier: "mock", ...)

let mockUser = User(id: "1", name: "测试用户")
mockProvider.mock("api/user", response: .success(mockUser, delay: 0.5))

Vega.regist(mockProvider)

@GET("api/user", .provider("mock"))
static var getUser: ActionModel<Empty, User>
#endif
```

---

## 实施优先级

### 高优先级（必须实现）

1. ✅ **完善 HTTP 方法支持** - 基础功能完整性
2. ✅ **增强错误处理** - 稳定性和调试体验
3. ✅ **Provider 管理改进** - 线程安全和容错
4. ✅ **请求取消机制** - 资源管理
5. ✅ **async/await 支持** - 现代化 API

### 中优先级（强烈推荐）

6. 自动重试策略 - 可靠性提升
7. 日志系统 - 开发和调试体验
8. Combine 支持 - SwiftUI 兼容性
9. Mock 支持 - 测试友好性

### 低优先级（可选）

10. 缓存策略 - 性能优化
11. 文件上传下载 - 特定场景需求
12. SSL Pinning - 高安全场景需求

---

## 实施路线图

### Phase 1: 核心稳定性（2-3周）

**目标**：提升框架稳定性和容错能力

- [ ] 错误处理重构
- [ ] Provider 管理改进
- [ ] HTTP 方法完善
- [ ] 单元测试覆盖

**验收标准**：
- 所有错误场景都有明确分类
- Provider 管理线程安全
- 支持 7 种 HTTP 方法
- 测试覆盖率 > 70%

---

### Phase 2: 现代化 API（2-3周）

**目标**：适配现代 Swift 特性

- [ ] async/await 支持
- [ ] Combine 支持
- [ ] 请求取消机制
- [ ] 泛型约束改进

**验收标准**：
- 所有请求支持 async/await
- Combine Publisher 完整支持
- 请求可正确取消
- 类型安全性提升

---

### Phase 3: 功能增强（3-4周）

**目标**：完善实用功能

- [ ] 重试策略实现
- [ ] 日志系统完善
- [ ] Mock 支持
- [ ] 请求去重

**验收标准**：
- 支持多种重试策略
- 日志分级完整
- Mock 系统可用于测试

---

## 总结

### 核心改进领域

1. **架构稳定性** - 错误处理、Provider 管理、线程安全
2. **现代化** - async/await、Combine、Swift 新特性
3. **实用功能** - 取消、重试、日志、Mock
4. **开发体验** - 类型安全、调试信息、文档

### 关键原则

- ✅ **保持向后兼容** - 不破坏现有 API
- ✅ **渐进式改进** - 分阶段实施
- ✅ **测试驱动** - 完善单元测试
- ✅ **文档同步** - 及时更新文档

### 预期收益

- 📈 **稳定性提升** 50%+
- 🚀 **开发效率提升** 30%+
- 🛡️ **错误处理完善** 90%+
- 📱 **现代化程度** 100%

---

**文档版本**: v1.0  
**更新时间**: 2025-12-05  
**适用版本**: Vega 重构版本

根据项目实际需求，可以选择性地实施以上建议。建议从高优先级项目开始，逐步完善框架功能。

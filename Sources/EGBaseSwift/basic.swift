//
//  basic.swift
//  EGBaseSwift
//
//  Converted from EGConstant Objective-C code
//

import Foundation
import UIKit

// MARK: - Type Aliases

public typealias EGVoidBlock = () -> Void
public typealias EGSuccessBlock = (Bool) -> Void
public typealias EGStatusBlock = (Bool, String?) -> Void
public typealias EGMessageBlock = (String?) -> Void

// MARK: - Adapted Functions

/// 检查是否是 iPad
public func EGIsIPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

// MARK: - Null Check Functions

/// 检查对象是否为空
public func IsNull(_ obj: Any?) -> Bool {
    guard let obj = obj else {
        return true
    }

    if obj is NSNull {
        return true
    }

    if let str = obj as? String {
        if str.isEmpty {
            return true
        }
        if str.replacingOccurrences(of: " ", with: "").isEmpty {
            return true
        }
    }

    return false
}

/// 检查对象是否非空
public func IsNonNull(_ obj: Any?) -> Bool {
    return !IsNull(obj)
}

/// 检查对象是否为空（包括空数组、字典等）
public func IsEmpty(_ obj: Any?) -> Bool {
    if IsNull(obj) {
        return true
    }

    guard let obj = obj else {
        return true
    }

    if let array = obj as? [Any] {
        var hasNull = false
        for element in array {
            if element is String {
                if IsNull(element) {
                    hasNull = true
                }
            } else if element is NSNull {
                hasNull = true
            }
        }
        if hasNull {
            return true
        }
        return array.isEmpty
    }

    if let dict = obj as? [AnyHashable: Any] {
        return dict.isEmpty
    }

    if let str = obj as? String {
        return str.isEmpty
    }

    if let set = obj as? Set<AnyHashable> {
        return set.isEmpty
    }

    if let num = obj as? NSNumber {
        return num.intValue == 0
    }

    if let data = obj as? Data {
        return data.isEmpty
    }

    return false
}

/// 检查对象是否非空（包括空数组、字典等）
public func IsNotEmpty(_ obj: Any?) -> Bool {
    return !IsEmpty(obj)
}

/// 如果为空则显示空字符串
public func NullShow(_ obj: Any?) -> String {
    if IsNull(obj) {
        return ""
    }

    guard let obj = obj else {
        return ""
    }

    if let str = obj as? String {
        return str
    }

    return "\(obj)"
}

/// 如果为空则显示设置的对象
public func NullShowSet(_ obj: Any?, _ setObj: Any) -> Any {
    if IsNull(obj) {
        return setObj
    }

    guard let obj = obj else {
        return setObj
    }

    if obj is String {
        return obj
    }

    return "\(obj)"
}

// MARK: - Log

/// 日志输出
public func EGLog(_ type: String, _ className: String, _ lineNum: Int, _ format: String, _ args: CVarArg...) {
    #if DEBUG
    let message = String(format: "[%@,%d]%@: %@", className, lineNum, type, format)
    withVaList(args) { pointer in
        NSLogv(message, pointer)
    }
    #endif
}

// MARK: - Dispatch

/// 主线程异步执行
@MainActor
public func EGDispatchAsyncMainBlock(_ block: EGVoidBlock?) {
    guard let block = block else {
        return
    }
    block()
}

// MARK: - Method Swizzling

/// 方法交换
public func eg_swizzleMethod(_ theClass: AnyClass, _ originalSelector: Selector, _ swizzledSelector: Selector) {
    guard let originalMethod = class_getInstanceMethod(theClass, originalSelector),
          let swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector) else {
        return
    }

    let didAddMethod = class_addMethod(theClass,
                                       originalSelector,
                                       method_getImplementation(swizzledMethod),
                                       method_getTypeEncoding(swizzledMethod))

    if didAddMethod {
        class_replaceMethod(theClass,
                          swizzledSelector,
                          method_getImplementation(originalMethod),
                          method_getTypeEncoding(originalMethod))
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

/// 类方法交换
public func eg_swizzleClassMethod(_ theClass: AnyClass, _ originalSelector: Selector, _ swizzledSelector: Selector) {
    guard let metaClass = object_getClass(theClass) else {
        return
    }
    eg_swizzleMethod(metaClass, originalSelector, swizzledSelector)
}

/// 检查是否是主 Bundle 中的类
public func eg_mainBundleClass(_ theClass: AnyClass) -> Bool {
    let inBundle = Bundle(for: theClass)
    let mainBundle = Bundle.main
    let inPath = inBundle.bundlePath
    var mainPath = mainBundle.privateFrameworksPath ?? ""

    if mainPath.hasPrefix(inPath) {
        return true
    }

    if mainPath.count > 20 {
        mainPath = String(mainPath.dropFirst(20))
    }

    if inPath.contains(mainPath) {
        return true
    } else {
        return false
    }
}

/// 本地化字符串
public func LS(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

// MARK: - Animation

/// 动画速率
private func EGAnimation_Rate() -> CGFloat {
    return 3.0
}

/// 线性动画
public func EGAnimation_Linear(_ t: CGFloat) -> CGFloat {
    return t
}

/// EaseIn 动画
public func EGAnimation_EaseIn(_ t: CGFloat) -> CGFloat {
    return Foundation.pow(t, EGAnimation_Rate())
}

/// EaseOut 动画
public func EGAnimation_EaseOut(_ t: CGFloat) -> CGFloat {
    return 1.0 - Foundation.pow(1.0 - t, EGAnimation_Rate())
}

/// EaseInOut 动画
public func EGAnimation_EaseInOut(_ t: CGFloat) -> CGFloat {
    var t = t * 2
    if t < 1 {
        return 0.5 * Foundation.pow(t, EGAnimation_Rate())
    } else {
        return 0.5 * (2.0 - Foundation.pow(2.0 - t, EGAnimation_Rate()))
    }
}

/// EaseInBounce 动画
public func EGAnimation_EaseInBounce(_ t: CGFloat) -> CGFloat {
    if t < 4.0 / 11.0 {
        return 1.0 - (Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t, 2)) - t
    }

    if t < 8.0 / 11.0 {
        return 1.0 - (3.0 / 4.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 6.0 / 11.0, 2)) - t
    }

    if t < 10.0 / 11.0 {
        return 1.0 - (15.0 / 16.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 9.0 / 11.0, 2)) - t
    }

    return 1.0 - (63.0 / 64.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 21.0 / 22.0, 2)) - t
}

/// EaseOutBounce 动画
public func EGAnimation_EaseOutBounce(_ t: CGFloat) -> CGFloat {
    if t < 4.0 / 11.0 {
        return Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t, 2)
    }

    if t < 8.0 / 11.0 {
        return 3.0 / 4.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 6.0 / 11.0, 2)
    }

    if t < 10.0 / 11.0 {
        return 15.0 / 16.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 9.0 / 11.0, 2)
    }

    return 63.0 / 64.0 + Foundation.pow(11.0 / 4.0, 2) * Foundation.pow(t - 21.0 / 22.0, 2)
}

// MARK: - URL

/// 解析 URL 参数
public func EGURLParseComponentParams(_ urlString: String?) -> [String: Any] {
    var queryParams: [String: Any] = [:]

    guard let urlString = urlString, !IsNull(urlString) else {
        return queryParams
    }

    guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let components = URLComponents(string: encodedString) else {
        return queryParams
    }

    var mutableComponents = components

    if let fragment = components.fragment {
        var fragmentContainsQueryParams = false
        if let fragmentComponents = URLComponents(string: fragment) {
            var fragComponents = fragmentComponents

            if fragComponents.query == nil && fragComponents.path != nil {
                fragComponents.query = fragComponents.path
            }

            if let queryItems = fragComponents.queryItems, !queryItems.isEmpty {
                fragmentContainsQueryParams = queryItems.first?.value?.isEmpty == false
            }

            if fragmentContainsQueryParams {
                let existingItems = mutableComponents.queryItems ?? []
                mutableComponents.queryItems = existingItems + (fragComponents.queryItems ?? [])
            }
        }
    }

    let queryItems = mutableComponents.queryItems ?? []
    for item in queryItems {
        guard let value = item.value else {
            continue
        }

        let decodedValue = value.removingPercentEncoding ?? value

        if queryParams[item.name] == nil {
            queryParams[item.name] = decodedValue
        } else if let existingArray = queryParams[item.name] as? [String] {
            queryParams[item.name] = existingArray + [decodedValue]
        } else if let existingValue = queryParams[item.name] {
            queryParams[item.name] = [existingValue, decodedValue]
        }
    }

    return queryParams
}

/// 参数拼接到链接中
public func EGURLParamsToLink(_ urlString: String?, _ params: [String: Any]?) -> URL? {
    guard let urlString = urlString else {
        return nil
    }

    let urlParams = EGURLParseComponentParams(urlString)
    var allParams = urlParams

    if let params = params {
        allParams.merge(params) { _, new in new }
    }

    guard let baseURL = URL(string: urlString),
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
        return nil
    }

    var queryItems: [URLQueryItem] = []
    for (key, value) in allParams {
        let item = URLQueryItem(name: key, value: "\(value)")
        queryItems.append(item)
    }

    components.queryItems = queryItems
    return components.url
}

// MARK: - Notification Names

extension Notification.Name {
    /// 用户登录成功
    public static let EGUserDidLogin = Notification.Name("EGserDidLoginNotiName")

    /// 登录信息 Token过期
    public static let EGLoginTokenExpire = Notification.Name("kEGLoginTokenExpireNotifition")

    /// 登录状态变化
    public static let EGLoginStatusChange = Notification.Name("kEGLoginStatusChangeNotifition")

    /// 用户信息变化
    public static let EGLoginUserInfoChange = Notification.Name("kEGLoginUserInfoChangeNotifition")
}

// MARK: - EGConstant Class

public class EGConstant: NSObject {

}

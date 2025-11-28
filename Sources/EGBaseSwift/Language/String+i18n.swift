//
//  String+i18n.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/26.
//

import Foundation

/// 多语言字符串转化
public extension String {
    var i18n: String {
        I18nManager.shared.i18n(key: self)
    }
    
    func i18n(_ param: CVarArg...) -> String {
        I18nManager.shared.i18n(key: self, param:param)
    }
    
    func i18n(in bundle: Bundle) -> String {
        I18nManager.shared.i18n(in: bundle, key: self, param: [])
    }
    
    func i18n(in bundle: Bundle, params: CVarArg...) -> String {
        I18nManager.shared.i18n(in: bundle, key: self, param: params)
    }
}

public class I18nManager: @unchecked Sendable {
    fileprivate static let unExistString: String = "\u{05}"
    
    public static let shared: I18nManager = .init()
    
    private var bundles: Set<Bundle> = .init()
    private var language: Language = .en_us
    
    private var languageBundles: [Bundle] = .init()
    private let lock: NSLock = .init()
}

public extension I18nManager {
    
    func register(bundles: [Bundle]) {
        lock.lock()
        defer { lock.unlock() }
        
        self.bundles.formUnion(bundles)
        updateLanguageBundles()
    }
    
    func resetBundles() {
        lock.lock()
        defer { lock.unlock() }
        
        bundles.removeAll()
        updateLanguageBundles()
    }
    
    func change(language: Language) {
        lock.lock()
        defer { lock.unlock() }
        
        self.language = language
        updateLanguageBundles()
    }
    
    func i18n(key: String) -> String {
        lock.lock()
        let languageBundles = self.languageBundles
        lock.unlock()
        
        var value = key
        for languageBundle in languageBundles {
            let text = i18n(languageBundle: languageBundle, key: key)
            if !text.isEmpty,
               text != value,
               text != Self.unExistString {
                value = text
                break
            }
        }
        return value
    }
    
    func i18n(in bundle: Bundle, key: String) -> String {
        guard let languageBundle = languageBundle(in: bundle) else {
            return key
        }
        
        let text = i18n(languageBundle: languageBundle, key: key)
        if !text.isEmpty,
           text != key,
           text != Self.unExistString {
            return text
        }
        return key
    }
    
    func i18n(in bundle: Bundle? = nil, key: String, param: [CVarArg]) -> String {
        let text = if let bundle {
            i18n(in: bundle, key: key)
        } else {
            i18n(key: key)
        }
#if DEBUG
        if DebugSetting.debugMode {
            validateFormatString(text, params: param, key: key)
        }
#endif
        return withVaList(param) { vaList in
            NSString(format: text, arguments: vaList) as String
        }
    }
}

private extension I18nManager {
    
    func updateLanguageBundles() {
        languageBundles = bundles.compactMap { languageBundle(in: $0) }
    }
    
    func languageBundle(in bundle: Bundle) -> Bundle? {
        guard let path = bundle.path(forResource: language.i18nCode, ofType: "lproj"),
              let langBundle = Bundle(path: path) else {
            return nil
        }
        return langBundle
    }
    
    func i18n(languageBundle: Bundle, key: String) -> String {
        return NSLocalizedString(key, bundle: languageBundle, value: Self.unExistString, comment: "")
    }

#if DEBUG
    /// 验证格式化字符串的参数匹配
    /// - Parameters:
    ///   - formatString: 格式化字符串（如 "Hello %@ %d"）
    ///   - params: 传入的参数数组
    ///   - key: 国际化 key（用于错误提示）
    func validateFormatString(_ formatString: String, params: [CVarArg], key: String) {
        // 解析格式化字符串中的占位符
        let formatSpecifiers = parseFormatSpecifiers(formatString)

        // 1. 验证参数数量
        assert(
            formatSpecifiers.count == params.count,
            """
            [国际化错误] Key '\(key)' 的参数数量不匹配
            期望参数数量: \(formatSpecifiers.count) 个
            实际参数数量: \(params.count) 个
            格式化字符串: '\(formatString)'
            占位符列表: \(formatSpecifiers)
            """
        )

        // 2. 验证参数类型
        for (index, specifier) in formatSpecifiers.enumerated() {
            guard index < params.count else { break }
            let param = params[index]
            let isValid = validateParamType(param, forSpecifier: specifier)

            assert(
                isValid,
                """
                [国际化错误] Key '\(key)' 的参数类型不匹配
                参数位置: 第 \(index + 1) 个
                期望类型 '\(specifier)': \(expectedType(for: specifier))
                实际类型: \(type(of: param))
                格式化字符串: '\(formatString)'
                """
            )
        }
    }

    /// 解析格式化字符串中的占位符
    func parseFormatSpecifiers(_ formatString: String) -> [String] {
        // 匹配 % 格式化占位符
        // 支持：%@, %d, %ld, %lld, %u, %lu, %llu, %f, %lf, %s, %%（转义）等
        let pattern = #"%(?:\d+\$)?[+-]?(?:\d+)?(?:\.\d+)?[hlqLztj]?[@dDiuUxXoOfFeEgGcCsSpaAn%]"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsString = formatString as NSString
        let matches = regex.matches(in: formatString, range: NSRange(location: 0, length: nsString.length))

        return matches.compactMap { match -> String? in
            let specifier = nsString.substring(with: match.range)
            // 过滤掉 %% 转义
            return specifier == "%%" ? nil : specifier
        }
    }

    /// 验证参数类型是否匹配格式化占位符
    func validateParamType(_ param: CVarArg, forSpecifier specifier: String) -> Bool {
        // 先检查是否为数值类型
        let isIntegerType = param is Int || param is Int8 || param is Int16 ||
                           param is Int32 || param is Int64 ||
                           param is UInt || param is UInt8 || param is UInt16 ||
                           param is UInt32 || param is UInt64
        let isFloatType = param is Double || param is Float || param is CGFloat

        // 提取类型字符（最后一个字符）
        let typeChar = specifier.last ?? Character("")

        switch typeChar {
        case "@":  // 对象类型（String, NSString, 数组等）
            // %@ 不应该接收数值类型
            if isIntegerType || isFloatType {
                return false
            }
            return param is AnyObject || param is String

        case "d", "D", "i":  // 有符号整数
            return isIntegerType

        case "u", "U":  // 无符号整数
            return isIntegerType

        case "x", "X", "o":  // 十六进制/八进制
            return isIntegerType

        case "f", "F", "e", "E", "g", "G":  // 浮点数
            return isFloatType

        case "c", "C":  // 字符
            return param is Int8 || param is UInt8 || param is Character

        case "s":  // C 字符串
            return param is UnsafePointer<CChar> || param is String

        case "p":  // 指针
            return true  // 任何类型都可以转为指针

        default:
            return true  // 未知类型，不做严格校验
        }
    }

    /// 获取格式化占位符期望的类型描述
    func expectedType(for specifier: String) -> String {
        let typeChar = specifier.last ?? Character("")

        switch typeChar {
        case "@": return "对象类型 (String, NSString 等)"
        case "d", "D", "i": return "有符号整数 (Int, Int32, Int64 等)"
        case "u", "U": return "无符号整数 (UInt, UInt32, UInt64 等)"
        case "x", "X", "o": return "整数 (十六进制/八进制)"
        case "f", "F", "e", "E", "g", "G": return "浮点数 (Double, Float, CGFloat)"
        case "c", "C": return "字符 (Int8, UInt8, Character)"
        case "s": return "C 字符串 (UnsafePointer<CChar>, String)"
        case "p": return "指针"
        default: return "未知类型"
        }
    }
#endif
}

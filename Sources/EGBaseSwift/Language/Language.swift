//
//  Language.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/26.
//

public enum Country {
    case Cambodia   // 柬埔寨
    case China      // 中国
    case Laos       // 老挝
    case Thailand   // 泰国
    case Vietnam    // 越南
}

public enum Language: CaseIterable {
    case zh_cn  // 中文
    case zh_tw  // 中文（繁體）
    case en_us  // 英语
    case km_kh  // 柬埔寨
    case lo_la  // 老挝
    case vi_vn  // 越南
    case th_th  // 泰语
    case ja_jp  // 日语
    case ko_kr  // 韩语
    case in_id  // 印尼
}

extension Language {
    var i18nCode: String {
        switch self {
        case .zh_cn:
            "zh-Hans"
        case .zh_tw:
            "zh-Hans-TW"
        case .en_us:
            "en"
        case .km_kh:
            "km"
        case .lo_la:
            "lo"
        case .vi_vn:
            "vi"
        case .th_th:
            "th"
        case .ja_jp:
            "ja"
        case .ko_kr:
            "ko"
        case .in_id:
            "id"
        }
    }
}

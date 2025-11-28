//
//  ScaleAdaptable.swift
//  EGBaseSwift
//
//  Created by E-GetS on 2025/11/24.
//

import Foundation
import UIKit

public protocol ScaleAdaptable {
    /// 转换为 CGFloat 用于计算
    var asCGFloat: CGFloat { get }

    /// 自适应后上取整
    var adaptedCeil: Int { get }
    /// 自适应后下取整
    var adaptedFloor: Int { get }
    /// 自适应后保留一位
    var adapted: CGFloat { get }
    /// 根据宽度比例自适应
    var adaptedWidth: CGFloat { get }
    /// 根据高度比例自适应
    var adaptedHeight: CGFloat { get }
    /// 自适应比例宽
    var adaptedWidthScale: CGFloat { get }
    /// 自适应比例高
    var adaptedHeightScale: CGFloat { get }
}

extension ScaleAdaptable {

    /// 自适应后上取整
    public var adaptedCeil: Int {
        let value = self.asCGFloat
        let negative = value < 0
        let adapted = Int(ceil(abs(value) * adaptedWidthScale))
        return negative ? -adapted : adapted
    }

    /// 自适应后下取整
    public var adaptedFloor: Int {
        let value = self.asCGFloat
        let negative = value < 0
        let adapted = Int(floor(abs(value) * adaptedWidthScale))
        return negative ? -adapted : adapted
    }

    /// 自适应后保留一位
    public var adapted: CGFloat {
        floor(self.asCGFloat * adaptedWidthScale * 10) * 0.1
    }

    /// 根据宽度比例自适应
    public var adaptedWidth: CGFloat {
        self.asCGFloat * adaptedWidthScale
    }

    /// 根据高度比例自适应
    public var adaptedHeight: CGFloat {
        self.asCGFloat * adaptedHeightScale
    }
    
    /// 自适应比例宽
    public var adaptedWidthScale: CGFloat {
        let size = UIScreen.main.bounds.size
        return min(size.width, size.height) / UIDevice.current.benchmark.width
    }
    
    /// 自适应比例高
    public var adaptedHeightScale: CGFloat {
        let size = UIScreen.main.bounds.size
        return max(size.width, size.height) / UIDevice.current.benchmark.height
    }
}

extension ScaleAdaptable where Self: BinaryInteger {
    public var asCGFloat: CGFloat {
        CGFloat(Int(self))
    }
}

extension ScaleAdaptable where Self: BinaryFloatingPoint {
    public var asCGFloat: CGFloat {
        CGFloat(Double(self))
    }
}

extension Int: ScaleAdaptable {}
extension Int8: ScaleAdaptable {}
extension Int16: ScaleAdaptable {}
extension Int32: ScaleAdaptable {}
extension Int64: ScaleAdaptable {}
extension UInt: ScaleAdaptable {}
extension UInt8: ScaleAdaptable {}
extension UInt16: ScaleAdaptable {}
extension UInt32: ScaleAdaptable {}
extension UInt64: ScaleAdaptable {}

extension Float: ScaleAdaptable {}
extension Double: ScaleAdaptable {}
extension CGFloat: ScaleAdaptable {}

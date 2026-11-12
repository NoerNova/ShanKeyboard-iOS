//
//  LayerGeometryGuard.swift
//  ShanKeyboard
//
//  Prevents the `CALayerInvalidGeometry` crash ("CALayer bounds contains NaN").
//
//  Created by NorHsangPha BoonHse on 12/11/2569 BE.
//

import ObjectiveC
import QuartzCore
import os

enum LayerGeometryGuard {
    private static let logger = Logger(subsystem: "com.noernova.ShanKeyboard.shan", category: "layout")
    private static let lock = OSAllocatedUnfairLock(initialState: 0)
    private static let maxReports = 20

    /// Safe to call more than once; installs on the first call only.
    static func install() { _ = installed }

    private static let installed: Void = {
        swizzleBounds()
        swizzlePosition()
    }()

    // MARK: - Swizzling

    private static func swizzleBounds() {
        let selector = #selector(setter: CALayer.bounds)
        guard let method = class_getInstanceMethod(CALayer.self, selector) else { return }
        typealias Setter = @convention(c) (CALayer, Selector, CGRect) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Setter.self)

        let replacement: @convention(block) (CALayer, CGRect) -> Void = { layer, rect in
            if !rect.hasNaN {
                original(layer, selector, rect)
            } else {
                report("bounds", value: "\(rect)", layer: layer)
                original(layer, selector, rect.sanitized)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }

    private static func swizzlePosition() {
        let selector = #selector(setter: CALayer.position)
        guard let method = class_getInstanceMethod(CALayer.self, selector) else { return }
        typealias Setter = @convention(c) (CALayer, Selector, CGPoint) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Setter.self)

        let replacement: @convention(block) (CALayer, CGPoint) -> Void = { layer, point in
            if !point.hasNaN {
                original(layer, selector, point)
            } else {
                report("position", value: "\(point)", layer: layer)
                original(layer, selector, point.sanitized)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }

    // MARK: - Reporting

    /// Logs the owning view chain, innermost first, e.g.
    /// "PlatformViewHost<…> < UIView < _UIHostingView<…>". Capped per process.
    private static func report(_ property: String, value: String, layer: CALayer) {
        let count = lock.withLock { count -> Int in
            count += 1
            return count
        }
        guard count <= maxReports else { return }

        var owners: [String] = []
        var current: CALayer? = layer
        while let l = current, owners.count < 8 {
            let owner = l.delegate.map { String(describing: type(of: $0)) } ?? String(describing: type(of: l))
            owners.append(owner)
            current = l.superlayer
        }
        logger.fault("""
            NaN layer \(property, privacy: .public) \(value, privacy: .public) \
            replaced with 0. Owners: \(owners.joined(separator: " < "), privacy: .public)
            """)
    }
}

// MARK: - NaN checks

private extension CGFloat {
    var nanToZero: CGFloat { isNaN ? 0 : self }
}

private extension CGRect {
    var hasNaN: Bool {
        origin.x.isNaN || origin.y.isNaN || size.width.isNaN || size.height.isNaN
    }

    var sanitized: CGRect {
        CGRect(x: origin.x.nanToZero, y: origin.y.nanToZero,
               width: size.width.nanToZero, height: size.height.nanToZero)
    }
}

private extension CGPoint {
    var hasNaN: Bool { x.isNaN || y.isNaN }
    var sanitized: CGPoint { CGPoint(x: x.nanToZero, y: y.nanToZero) }
}

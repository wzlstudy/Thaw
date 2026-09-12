//
//  LiquidGlassCompatibility.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

// MARK: - ThawGlassStyle

/// A description of a Liquid Glass effect that doesn't reference the
/// macOS-26-only `Glass` type, so call sites stay available on older systems.
nonisolated enum ThawGlassStyle {
    /// Standard glass.
    case regular
    /// Standard glass with press/interaction highlighting.
    case regularInteractive
    /// Clear glass.
    case clear
    /// Clear glass carrying the given tint color.
    case clearTinted(Color)
}

// MARK: - Glass Mapping

@available(macOS 26.0, *)
nonisolated extension ThawGlassStyle {
    /// The framework glass value this style stands for.
    var glass: Glass {
        switch self {
        case .regular: .regular
        case .regularInteractive: .regular.interactive()
        case .clear: .clear
        case .clearTinted(let tint): .clear.tint(tint)
        }
    }
}

// MARK: - ThawScrollEdgeEffectStyle

/// A description of a scroll edge effect that doesn't reference the
/// macOS-26-only `ScrollEdgeEffectStyle` type.
nonisolated enum ThawScrollEdgeEffectStyle {
    /// The system decides the effect based on the content.
    case automatic
    /// A hard-edged effect for solid content backgrounds.
    case soft
}

@available(macOS 26.0, *)
nonisolated extension ThawScrollEdgeEffectStyle {
    /// The framework style this value stands for.
    var scrollEdgeEffectStyle: ScrollEdgeEffectStyle? {
        switch self {
        case .automatic: .automatic
        case .soft: .soft
        }
    }
}

// MARK: - View Compatibility

@MainActor extension View {
    /// Pins a bar to a vertical safe-area edge: `safeAreaBar` on macOS 26
    /// and later, the equivalent `safeAreaInset` on older systems.
    @ViewBuilder
    func thawSafeAreaBar(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if #available(macOS 26.0, *) {
            safeAreaBar(edge: edge, alignment: alignment, spacing: spacing, content: content)
        } else {
            safeAreaInset(edge: edge, alignment: alignment, spacing: spacing, content: content)
        }
    }

    /// Styles the scroll edge effect on macOS 26 and later; below that,
    /// scroll views render no edge effect and this is a no-op.
    @ViewBuilder
    func thawScrollEdgeEffectStyle(_ style: ThawScrollEdgeEffectStyle, for edges: Edge.Set) -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(style.scrollEdgeEffectStyle, for: edges)
        } else {
            self
        }
    }

    /// Applies Liquid Glass on macOS 26 and later; older systems get the
    /// closest standard vibrancy treatment in the same shape.
    @ViewBuilder
    func thawGlassEffect(_ style: ThawGlassStyle = .regular, in shape: some Shape) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(style.glass, in: shape)
        } else {
            thawGlassFallback(style, in: shape)
        }
    }

    /// Applies the glass button style on macOS 26 and later; older systems
    /// fall back to the standard bordered styles.
    @ViewBuilder
    func thawGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// The pre-macOS-26 stand-in for a glass effect.
    @ViewBuilder
    private func thawGlassFallback(_ style: ThawGlassStyle, in shape: some Shape) -> some View {
        switch style {
        case .regular, .regularInteractive, .clear:
            background(.ultraThinMaterial, in: shape)
        case .clearTinted(let tint):
            background(.ultraThinMaterial, in: shape)
                .background(tint, in: shape)
        }
    }
}

// MARK: - ThawGlassEffectContainer

/// A compatibility wrapper around `GlassEffectContainer`.
///
/// On macOS 26 and later this passes through to the framework container so
/// sibling glass effects blend; older systems simply render the content.
nonisolated struct ThawGlassEffectContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(content: content)
        } else {
            content()
        }
    }
}

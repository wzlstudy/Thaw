//
//  ThawGlassEffectView.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit

/// A glass-effect backing view on macOS 26 and later, with a vibrancy-based
/// stand-in on older systems.
///
/// The view embeds the real `NSGlassEffectView` where it exists and an
/// `NSVisualEffectView` below that, exposing the small surface the app needs:
/// a style, a corner radius, and an embedded content view. Call sites can
/// treat it as the glass view regardless of what the running system offers.
@MainActor
final class ThawGlassEffectView: NSView {
    /// The backing effect view: an `NSGlassEffectView` on macOS 26 and
    /// later, an `NSVisualEffectView` below.
    private let backingView: NSView

    /// The glass view on macOS 26 and later, `nil` below.
    /// The glass view on macOS 26 and later, `nil` below.
    ///
    /// Named ``glassBacking`` to avoid the system `NSView.glassEffectView`.
    @available(macOS 26.0, *)
    private var glassBacking: NSGlassEffectView? {
        backingView as? NSGlassEffectView
    }

    /// The glass style the backing view renders.
    var style: ThawGlassStyle = .regular {
        didSet {
            applyStyle()
        }
    }

    /// The curvature of the glass corners.
    var cornerRadius: CGFloat = 0 {
        didSet {
            applyCornerRadius()
        }
    }

    /// The view embedded in the glass, or layered above the vibrancy on
    /// older systems.
    var contentView: NSView? {
        didSet {
            guard contentView !== oldValue else { return }
            oldValue?.removeFromSuperview()
            if let contentView {
                embed(contentView)
            }
        }
    }

    init() {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            backingView = glassView
        } else {
            let effectView = NSVisualEffectView()
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            backingView = effectView
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        backingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backingView)
        pinEdges(of: backingView, to: self)
        applyStyle()
        applyCornerRadius()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func embed(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 26.0, *), let glassBacking {
            glassBacking.contentView = view
            pinEdges(of: view, to: glassBacking)
        } else {
            addSubview(view, positioned: .above, relativeTo: nil)
            pinEdges(of: view, to: self)
        }
    }

    private func pinEdges(of view: NSView, to target: NSView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: target.topAnchor),
            view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: target.bottomAnchor),
        ])
    }

    private func applyStyle() {
        if #available(macOS 26.0, *), let glassBacking {
            glassBacking.style = style.nsGlassStyleIfAvailable
        } else if let effectView = backingView as? NSVisualEffectView {
            switch style {
            case .regular, .regularInteractive:
                effectView.material = .hudWindow
            case .clear, .clearTinted:
                effectView.material = .popover
            }
        }
    }

    private func applyCornerRadius() {
        if #available(macOS 26.0, *), let glassBacking {
            glassBacking.cornerRadius = cornerRadius
        } else if let effectView = backingView as? NSVisualEffectView {
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.masksToBounds = cornerRadius > 0
        }
    }
}

nonisolated extension ThawGlassStyle {
    /// The framework glass style for this value; only callable on systems
    /// that have `NSGlassEffectView`.
    @available(macOS 26.0, *)
    var nsGlassStyleIfAvailable: NSGlassEffectView.Style {
        switch self {
        case .regular, .regularInteractive: .regular
        case .clear, .clearTinted: .clear
        }
    }
}

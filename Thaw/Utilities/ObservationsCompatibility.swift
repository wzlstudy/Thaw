//
//  ObservationsCompatibility.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Observation

/// A deployment-target-safe stand-in for the `Observations` async sequence
/// that the Observation framework ships with macOS 26.
///
/// This module-level function shadows the framework type on every OS version,
/// so the app uses one observation pipeline everywhere. Call sites read
/// exactly like the framework API: the closure's current value is yielded as
/// soon as iteration begins, and again each time an observable property the
/// closure accessed changes.
///
/// The tracking is re-registered after every signal, and the value read at
/// re-registration is the latest one, so a mutation that lands between a
/// signal and the next registration is still delivered — it rides along with
/// the next read. What can be lost is precision, not updates: bursts of
/// mutations that arrive while the consumer is busy are coalesced into a
/// single yield carrying the newest value, and yields are not deduplicated.
/// Both match how the app used the framework API: consumers that care about
/// identity guard with their own `!= previous` check.
///
/// The function is main-actor bound: the app's default actor isolation is
/// `MainActor`, so every `Observations { }` call site is already isolated
/// there, and the closure reads main-actor state synchronously — the shape
/// the framework version supported through its dynamic-isolation parameter.
@MainActor
func Observations<Element: Sendable>(
    _ emit: @escaping () -> Element
) -> AsyncStream<Element> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                // (Re-)register the closure's observable accesses and read the
                // value they currently produce. The signal stream fires when
                // any tracked property mutates afterwards.
                let signal = AsyncStream<Void>.makeStream()
                let value = withObservationTracking {
                    emit()
                } onChange: {
                    signal.continuation.yield(())
                }
                continuation.yield(value)

                // Wait for the next change, then loop to re-register. Keeping
                // the registration outstanding until here leaves no window
                // where mutations go unobserved.
                var sawChange = false
                for await _ in signal.stream {
                    sawChange = true
                    break
                }
                if !sawChange {
                    break
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}

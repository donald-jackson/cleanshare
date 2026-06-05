import SwiftUI

/// Brand colours + reusable styling primitives (gradients, button styles).
///
/// Kept `public` so the share-extension target can reuse the same gradient
/// behind the "Cleaned & ready" success state without duplicating literals.
/// PLAN.md §14.2.
public enum BrandPalette {
    /// Teal `#19B4B0` — the top of the brand gradient.
    public static let teal = Color(red: 0.098, green: 0.706, blue: 0.690)
    /// Indigo `#3B3FB8` — the bottom of the brand gradient.
    public static let indigo = Color(red: 0.231, green: 0.247, blue: 0.722)
    /// Ink `#0B0F1A` — primary text on light surfaces.
    public static let ink = Color(red: 0.043, green: 0.059, blue: 0.102)
    /// Paper `#F8FAFC` — page background on light surfaces.
    public static let paper = Color(red: 0.973, green: 0.980, blue: 0.988)

    /// The diagonal teal→indigo gradient used by primary CTAs, the app icon,
    /// onboarding pages, and the share-extension "ready" success state.
    public static let gradient = LinearGradient(
        colors: [teal, indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Primary call-to-action button — full-width capsule with the brand gradient,
/// semibold white SF Pro Rounded text, and a soft drop shadow. Use for the
/// hero action on any screen (e.g. "Clean photos…" on `RootView`).
public struct CleanSharePrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(BrandPalette.gradient)
            .clipShape(Capsule(style: .continuous))
            .shadow(color: BrandPalette.indigo.opacity(0.28), radius: 16, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Secondary action — tinted capsule with indigo text. Use alongside the
/// primary CTA for less prominent actions ("Try on a sample photo", etc).
public struct CleanShareSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(BrandPalette.indigo)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(BrandPalette.indigo.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.indigo.opacity(0.18), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

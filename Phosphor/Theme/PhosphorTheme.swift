import SwiftUI

/// Phosphor design tokens — "warm black, one light."
///
/// The blacks are tinted warm (oklch hue ~70) like the glass of an old scope, so
/// the green reads cool and electric against them. `phosphor` is the only accent;
/// red and amber appear for genuine errors and the paused state, nothing else.
///
/// Glow is a *status*, not a decoration: only apply it to things that are on.
enum PhosphorTheme {

    // MARK: - Ink

    /// Page background.
    static let ink950 = Color(hex: 0x0B0908)
    /// Band / recessed background.
    static let ink925 = Color(hex: 0x0D0B09)
    /// Card and grouped-row surface.
    static let ink900 = Color(hex: 0x120F0D)
    /// Raised surface, one step above a card.
    static let ink850 = Color(hex: 0x191613)
    /// Pressed / highlighted surface.
    static let ink800 = Color(hex: 0x221E1A)
    /// Hairlines and dividers when they need to be visible.
    static let ink700 = Color(hex: 0x36322E)
    /// An "off" indicator dot.
    static let ink600 = Color(hex: 0x4A453F)
    /// Muted text — captions, units, metadata.
    static let ink400 = Color(hex: 0x8A847D)
    /// Secondary text — body copy.
    static let ink300 = Color(hex: 0xB6B0A9)
    /// Primary text.
    static let ink50 = Color(hex: 0xF6F3EE)

    // MARK: - Phosphor

    /// Hover / lighter step.
    static let phosphor300 = Color(hex: 0x8BFFAA)
    /// The light. The hero accent, and the only one.
    static let phosphor = Color(hex: 0x39FF7A)
    /// Pressed step.
    static let phosphor500 = Color(hex: 0x02E36A)
    /// For phosphor text on a light background — meets WCAG AA.
    static let phosphor600 = Color(hex: 0x00B152)

    /// Kept for source compatibility with earlier call sites.
    static let accent = phosphor
    static let accentAccessible = phosphor600
    static let accentMuted = phosphor.opacity(0.15)

    // MARK: - Signal

    /// Genuine errors only.
    static let signalRed = Color(hex: 0xFF645F)
    /// The paused state.
    static let signalAmber = Color(hex: 0xF3BA26)

    // MARK: - Alpha helpers

    /// Hairline borders on cards and rows.
    static let line = ink50.opacity(0.08)
    /// Dividers inside a grouped card.
    static let lineSoft = ink50.opacity(0.06)
    /// Border on an interactive ghost surface.
    static let lineStrong = ink50.opacity(0.14)
    /// Neutral fill — ghost buttons, segmented tracks.
    static let fill = ink50.opacity(0.06)
    /// Neutral fill, pressed.
    static let fillPressed = ink50.opacity(0.12)
    /// Phosphor-tinted fill behind icons and pills that are on.
    static let phosphorTint = phosphor.opacity(0.10)
    /// Phosphor-tinted border.
    static let phosphorEdge = phosphor.opacity(0.25)

    // MARK: - Shape

    /// Cards and grouped containers.
    static let cardRadius: CGFloat = 20
    /// Inner tiles and rows nested in a card.
    static let tileRadius: CGFloat = 16
    /// Buttons and segmented controls.
    static let controlRadius: CGFloat = 14
    /// Icon badges.
    static let badgeRadius: CGFloat = 10

    // MARK: - Motion

    /// Standard animation for data changes.
    static let dataAnimation: Animation = .easeInOut(duration: 0.3)
    /// Snappier animation for direct manipulation — toggles, segments.
    static let controlAnimation: Animation = .spring(response: 0.28, dampingFraction: 0.82)
    /// The afterglow decay: a live dot rings outward and fades over 2.4s.
    static let afterglowDuration: Double = 2.4

    // MARK: - Type roles
    //
    // The brand pairs a grotesque for prose with a mono for data. Bundling
    // Hanken Grotesk and JetBrains Mono would cost two font files and forfeit
    // Dynamic Type's optical sizing, so the roles map onto the system faces:
    // prose keeps SF, and anything that is *fact* — counts, rule totals,
    // timestamps, eyebrow labels — switches to the monospaced design. The
    // reader can still tell data from prose at a glance, which is the point.

    /// Numerals and other data that should read as fact.
    static func data(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// The small uppercase mono label that opens a section.
    static let eyebrow: Font = .system(size: 12, weight: .medium, design: .monospaced)
}

// MARK: - Hex

extension Color {
    /// Builds an sRGB colour from a `0xRRGGBB` literal, so the tokens above read
    /// the same here as they do in the brand guidelines.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

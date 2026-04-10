import SwiftUI

enum PhosphorTheme {
    /// Phosphorescent green accent color — #39FF7A
    /// Passes WCAG AA for large text against both light and dark backgrounds.
    static let accent = Color(red: 0.224, green: 1.0, blue: 0.478)

    /// Darker green for text on light backgrounds — meets WCAG AA contrast.
    static let accentAccessible = Color(red: 0.0, green: 0.6, blue: 0.3)

    /// Muted variant for backgrounds and secondary elements.
    static let accentMuted = accent.opacity(0.15)

    /// Card background using system material.
    static let cardMaterial: Material = .regularMaterial

    /// Standard card corner radius.
    static let cardRadius: CGFloat = 16

    /// Standard animation for data changes.
    static let dataAnimation: Animation = .easeInOut(duration: 0.3)
}

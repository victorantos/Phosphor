import SwiftUI

// MARK: - Surfaces

extension View {
    /// Paints the warm-black page background behind a scrolling screen.
    func phosphorPage() -> some View {
        background(PhosphorTheme.ink950.ignoresSafeArea())
    }
}

/// A card: warm-black surface, hairline border, generous radius.
struct PhosphorCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = PhosphorTheme.cardRadius
    /// A card that is "on" carries a soft phosphor bloom and a tinted edge.
    var lit: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(PhosphorTheme.ink900)
                    .overlay {
                        if lit {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [PhosphorTheme.phosphor.opacity(0.14), .clear],
                                        center: .bottom,
                                        startRadius: 0,
                                        endRadius: 220
                                    )
                                )
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(lit ? PhosphorTheme.phosphorEdge : PhosphorTheme.line, lineWidth: 1)
            }
    }
}

/// A grouped container whose children are full-bleed rows separated by hairlines.
struct PhosphorGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                    .fill(PhosphorTheme.ink900)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                    .strokeBorder(PhosphorTheme.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous))
    }
}

/// The hairline between two rows of a `PhosphorGroup`.
struct PhosphorDivider: View {
    var inset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(PhosphorTheme.lineSoft)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// MARK: - Labels

/// The mono, uppercase, letterspaced label that opens a section.
struct SectionLabel: View {
    let text: String
    var tint: Color = PhosphorTheme.ink400

    init(_ text: String, tint: Color = PhosphorTheme.ink400) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text.uppercased())
            .font(PhosphorTheme.eyebrow)
            .tracking(1.0)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Mark

/// The Phosphor mark: a stem and a lit dot. Drawn on the brand's 64-unit grid.
///
/// Below 32pt the halo rings are dropped — they turn to mud at that size.
struct PhosphorMark: View {
    var size: CGFloat = 28
    var showsHalo: Bool = true

    private var halo: Bool { showsHalo && size >= 32 }

    var body: some View {
        let u = size / 64

        ZStack(alignment: .topLeading) {
            if halo {
                Circle()
                    .fill(PhosphorTheme.phosphor.opacity(0.07))
                    .frame(width: 40 * u, height: 40 * u)
                    .offset(x: 18 * u, y: 2 * u)
                Circle()
                    .fill(PhosphorTheme.phosphor.opacity(0.16))
                    .frame(width: 30 * u, height: 30 * u)
                    .offset(x: 23 * u, y: 7 * u)
            }
            RoundedRectangle(cornerRadius: 5 * u, style: .continuous)
                .fill(PhosphorTheme.ink50)
                .frame(width: 10 * u, height: 40 * u)
                .offset(x: 16 * u, y: 12 * u)
            Circle()
                .fill(PhosphorTheme.phosphor)
                .frame(width: 20 * u, height: 20 * u)
                .offset(x: 28 * u, y: 12 * u)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// Mark plus lowercase wordmark.
struct PhosphorWordmark: View {
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: size * 0.4) {
            PhosphorMark(size: size)
            Text("phosphor")
                .font(.system(size: size * 0.78, weight: .bold))
                .kerning(-size * 0.03)
                .foregroundStyle(PhosphorTheme.ink50)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phosphor")
    }
}

// MARK: - Afterglow

/// A live dot that rings outward and fades — real phosphor keeps glowing after
/// the beam has moved on. Only use it for something that is actually running.
struct PulseDot: View {
    var size: CGFloat = 10
    var isLive: Bool = true
    var color: Color = PhosphorTheme.phosphor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            if isLive && !reduceMotion {
                ring(delay: 0)
                ring(delay: PhosphorTheme.afterglowDuration / 2)
            }
            Circle()
                .fill(color)
                .shadow(color: isLive ? color.opacity(0.8) : .clear, radius: size * 0.55)
        }
        .frame(width: size, height: size)
        .onAppear { expanded = true }
        .accessibilityHidden(true)
    }

    private func ring(delay: Double) -> some View {
        Circle()
            .fill(color)
            .opacity(expanded ? 0 : 0.55)
            .scaleEffect(expanded ? 2.6 : 1)
            .animation(
                .easeOut(duration: PhosphorTheme.afterglowDuration)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: expanded
            )
    }
}

// MARK: - Meters

/// A single-hue meter. Rank is carried by opacity, never by a second colour;
/// only the leading bar is allowed to glow.
struct PhosphorBar: View {
    var fraction: Double
    var emphasis: Double = 1.0
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PhosphorTheme.ink50.opacity(0.08))
                Capsule()
                    .fill(PhosphorTheme.phosphor.opacity(emphasis))
                    .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                    .shadow(
                        color: emphasis >= 1 ? PhosphorTheme.phosphor.opacity(0.6) : .clear,
                        radius: 5
                    )
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Icon badge

/// The rounded-square icon tile that fronts a feature row or a list entry.
struct IconBadge: View {
    let systemImage: String
    var isOn: Bool = true
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: PhosphorTheme.badgeRadius, style: .continuous)
            .fill(isOn ? PhosphorTheme.phosphorTint : PhosphorTheme.fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(isOn ? PhosphorTheme.phosphor : PhosphorTheme.ink400)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// The one filled button: phosphor on ink, glowing while idle, dimming on press.
struct PhosphorPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PhosphorTheme.ink950)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.controlRadius, style: .continuous)
                    .fill(configuration.isPressed ? PhosphorTheme.phosphor500 : PhosphorTheme.phosphor)
            }
            .shadow(color: PhosphorTheme.phosphor.opacity(configuration.isPressed ? 0 : 0.35), radius: 18)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PhosphorTheme.controlAnimation, value: configuration.isPressed)
    }
}

/// The quiet counterpart: a neutral fill with a hairline edge.
struct PhosphorGhostButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PhosphorTheme.ink50)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.controlRadius, style: .continuous)
                    .fill(configuration.isPressed ? PhosphorTheme.fillPressed : PhosphorTheme.fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PhosphorTheme.controlRadius, style: .continuous)
                    .strokeBorder(PhosphorTheme.lineStrong, lineWidth: 1)
            }
            .animation(PhosphorTheme.controlAnimation, value: configuration.isPressed)
    }
}

/// A small tinted pill — "Add", "Update now", and other inline affordances.
struct PhosphorPillButtonStyle: ButtonStyle {
    var tinted: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tinted ? PhosphorTheme.phosphor : PhosphorTheme.ink300)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tinted ? PhosphorTheme.phosphorTint : PhosphorTheme.fill)
                    .opacity(configuration.isPressed ? 0.6 : 1)
            }
    }
}

/// Makes a whole row tappable without the blue-tinted default button look.
struct PhosphorRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? PhosphorTheme.fill : .clear)
    }
}

// MARK: - Toggle

/// The brand switch: phosphor track with a glow when on, neutral when off.
struct PhosphorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(PhosphorTheme.controlAnimation) { configuration.isOn.toggle() }
        } label: {
            Capsule()
                .fill(configuration.isOn ? PhosphorTheme.phosphor : PhosphorTheme.ink50.opacity(0.14))
                .frame(width: 51, height: 31)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(PhosphorTheme.ink50)
                        .frame(width: 27, height: 27)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                        .padding(2)
                }
                .shadow(color: PhosphorTheme.phosphor.opacity(configuration.isOn ? 0.35 : 0), radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

// MARK: - Segmented control

/// A segmented control that can tint its selection — phosphor for a normal
/// choice, amber when the selection means "paused".
struct PhosphorSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var tint: (Value) -> Color = { _ in PhosphorTheme.phosphor }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                let accent = tint(option.value)

                Button {
                    withAnimation(PhosphorTheme.controlAnimation) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : PhosphorTheme.ink400)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? accent.opacity(0.16) : .clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PhosphorTheme.fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(PhosphorTheme.line, lineWidth: 1)
        }
    }
}

// MARK: - Rows

/// A grouped-card row: title, optional subtitle in the data face, optional
/// trailing detail, and a chevron when it navigates.
struct PhosphorRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var showsChevron: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                if let subtitle {
                    Text(subtitle)
                        .font(PhosphorTheme.data(12, weight: .regular))
                        .foregroundStyle(PhosphorTheme.ink400)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

extension PhosphorRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, showsChevron: Bool = false) {
        self.init(title: title, subtitle: subtitle, showsChevron: showsChevron) { EmptyView() }
    }
}

/// The small trailing value on a settings row.
struct PhosphorRowValue: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? PhosphorTheme.data(13, weight: .regular) : .system(size: 15))
            .foregroundStyle(PhosphorTheme.ink400)
    }
}

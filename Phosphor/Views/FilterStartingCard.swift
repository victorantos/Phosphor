import SwiftUI

/// Shown while the filter is switched on but not running yet.
///
/// A first start, and every start after a pause or a renewed subscription, takes a
/// few minutes: iOS fetches Privacy Pass tokens and sets up encrypted lookups before it
/// filters anything. Without an explanation that wait looks like a broken app.
struct FilterStartingCard: View {
    /// When the app first saw the filter starting; nil if not known.
    let since: Date?
    let restart: () async -> Void

    @State private var isRestarting = false

    /// After this long, starting is no longer normal and the card offers help.
    private static let slowAfter: TimeInterval = 10 * 60

    var body: some View {
        PhosphorCard(padding: 24, radius: 22) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = since.map { context.date.timeIntervalSince($0) }
                content(elapsed: elapsed)
            }
        }
    }

    private func content(elapsed: TimeInterval?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                PulseDot(size: 10, isLive: true, color: PhosphorTheme.signalAmber)
                Text("Turning on protection")
                    .font(.system(size: 24, weight: .bold))
                    .kerning(-0.6)
                    .foregroundStyle(PhosphorTheme.ink50)
            }

            VStack(alignment: .leading, spacing: 14) {
                step("Filter switched on", detail: nil, state: .done)
                step(
                    "Setting up private lookups",
                    detail: elapsed.map { "Usually 2–5 minutes · \(Self.format($0)) so far" }
                        ?? "Usually 2–5 minutes",
                    state: .active
                )
                step("Blocking starts", detail: nil, state: .pending)
            }

            Text("iOS is getting the encrypted access it needs to check sites without anyone seeing them. You can leave the app; this carries on in the background. Sites load normally until it's ready.")
                .font(.system(size: 14))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)

            if let elapsed, elapsed > Self.slowAfter {
                slowHelp
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var slowHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Taking longer than usual?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PhosphorTheme.ink50)
            Text("Check that you are online, then restart the filter. If it still doesn't start, restarting the phone usually helps.")
                .font(.system(size: 14))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                isRestarting = true
                Task {
                    await restart()
                    isRestarting = false
                }
            } label: {
                if isRestarting {
                    ProgressView().tint(PhosphorTheme.ink50)
                } else {
                    Text("Restart filter")
                }
            }
            .buttonStyle(PhosphorGhostButtonStyle(height: 46))
            .disabled(isRestarting)
        }
        .padding(.top, 2)
    }

    private enum StepState { case done, active, pending }

    private func step(_ title: String, detail: String?, state: StepState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PhosphorTheme.phosphor)
                case .active:
                    ProgressView()
                        .controlSize(.small)
                        .tint(PhosphorTheme.signalAmber)
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(PhosphorTheme.ink600)
                }
            }
            .font(.system(size: 18))
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: state == .active ? .semibold : .regular))
                    .foregroundStyle(state == .pending ? PhosphorTheme.ink400 : PhosphorTheme.ink50)
                if let detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    FilterStartingCard(since: .now.addingTimeInterval(-95)) {}
        .padding()
        .background(PhosphorTheme.ink950)
        .preferredColorScheme(.dark)
}

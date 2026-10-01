import NetworkExtension
import PhosphorShared
import SwiftUI

struct DashboardView: View {
    @Binding var selection: PhosphorTab

    @State private var viewModel = DashboardViewModel()
    @State private var hasAppeared = false
    @State private var showingPaywall = false

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    private var isFilterRunning: Bool {
        viewModel.filterIsEnabled && viewModel.filterStatus == "Running"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header

                    if !subscriptionManager.isSubscribed {
                        premiumBanner
                    }

                    if viewModel.totalBlocks == 0 {
                        emptyState
                    } else {
                        statsContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .phosphorPage()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { viewModel.load() }
            .task { await viewModel.observeFilterStatus() }
            .sheet(isPresented: $showingPaywall, onDismiss: subscriptionChanged) {
                PaywallView()
            }
            .onAppear {
                viewModel.load()
                withAnimation(PhosphorTheme.dataAnimation) { hasAppeared = true }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            PhosphorWordmark(size: 22)
            Spacer()
            statusPill
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            PulseDot(size: 8, isLive: isFilterRunning, color: statusColor)
            Text(isFilterRunning ? "Active" : viewModel.filterStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PhosphorTheme.ink50)
        }
        .padding(.leading, 11)
        .padding(.trailing, 12)
        .frame(height: 34)
        .background(Capsule().fill(statusColor.opacity(0.08)))
        .overlay(Capsule().strokeBorder(statusColor.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Filter status: \(isFilterRunning ? "active" : viewModel.filterStatus)")
    }

    private var statusColor: Color {
        switch viewModel.filterStatus {
        case "Running": PhosphorTheme.phosphor
        case "Starting", "Stopping", "Stopped": PhosphorTheme.signalAmber
        default: PhosphorTheme.signalRed
        }
    }

    // MARK: - Premium

    /// Filtering needs Premium. Says plainly why protection is off and how to get it back.
    private var premiumBanner: some View {
        let lapsed = SubscriptionGate.isPausedForSubscription
        return PhosphorCard(padding: 20, radius: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(lapsed ? "Protection paused" : "Filtering is off")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PhosphorTheme.ink50)
                Text(lapsed
                     ? "Phosphor Premium has ended, so nothing is being blocked. Renew to resume."
                     : "Filtering comes with Phosphor Premium. New subscribers get 7 days free.")
                    .font(.system(size: 15))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)
                Button(lapsed ? "Renew" : "Start free trial") { showingPaywall = true }
                    .buttonStyle(PhosphorPrimaryButtonStyle(height: 48))
                    .padding(.top, 6)
            }
        }
    }

    /// After a purchase the app re-enables a paused filter by itself. A filter that was
    /// never set up still needs the setup screen.
    private func subscriptionChanged() {
        guard subscriptionManager.isSubscribed else { return }
        Task {
            await SubscriptionGate.run()
            let manager = NEURLFilterManager.shared
            try? await manager.loadFromPreferences()
            if manager.pirServerURL == nil {
                hasCompletedOnboarding = false
            } else {
                viewModel.load()
            }
        }
    }

    // MARK: - Stats

    private var statsContent: some View {
        VStack(spacing: 12) {
            heroCard
            periodTiles
            categoryCard
            trendCard
            activeListsRow
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
    }

    private var heroCard: some View {
        PhosphorCard(padding: 24, radius: 22, lit: true) {
            VStack(spacing: 8) {
                Text("Blocked today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink400)

                Text(viewModel.todayBlocks.formatted())
                    .font(PhosphorTheme.data(62))
                    .kerning(-3)
                    .foregroundStyle(PhosphorTheme.phosphor)
                    .shadow(color: PhosphorTheme.phosphor.opacity(0.45), radius: 22)
                    .contentTransition(.numericText())
                    .animation(PhosphorTheme.dataAnimation, value: viewModel.todayBlocks)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("threats stopped")
                    .font(.system(size: 14))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.todayBlocks) threats blocked today")
    }

    private var periodTiles: some View {
        HStack(spacing: 10) {
            PeriodTile(title: "This week", count: viewModel.weekBlocks)
            PeriodTile(title: "This month", count: viewModel.monthBlocks)
            PeriodTile(title: "All time", count: viewModel.totalBlocks)
        }
    }

    // MARK: - By category

    private var categoryCard: some View {
        PhosphorCard(radius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                cardHead("By category", trailing: "today")

                if viewModel.categoryBreakdown.isEmpty {
                    Text("No data yet")
                        .font(.system(size: 14))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    let ranked = viewModel.categoryBreakdown.sorted { $0.count > $1.count }
                    let peak = max(ranked.first?.count ?? 1, 1)

                    VStack(spacing: 9) {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, point in
                            categoryRow(point, peak: peak, rank: index)
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(_ point: DashboardViewModel.CategoryDataPoint, peak: Int, rank: Int) -> some View {
        // Rank is carried by opacity alone — there is no second accent colour.
        let emphasis = [1.0, 0.75, 0.5, 0.35][min(rank, 3)]

        return HStack(spacing: 10) {
            Text(point.category.displayName)
                .font(.system(size: 13))
                .foregroundStyle(PhosphorTheme.ink50)
                .frame(width: 76, alignment: .leading)
                .lineLimit(1)

            PhosphorBar(fraction: Double(point.count) / Double(peak), emphasis: emphasis)

            Text(point.count.formatted())
                .font(PhosphorTheme.data(12, weight: .regular))
                .foregroundStyle(PhosphorTheme.ink400)
                .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(point.category.displayName): \(point.count) blocks")
    }

    // MARK: - 14-day trend

    private var trendCard: some View {
        let trend = viewModel.dailyTrend(days: 14)
        let peak = max(trend.map(\.count).max() ?? 0, 1)

        return PhosphorCard(radius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                cardHead("14-day trend", trailing: trendRange(trend))

                if trend.allSatisfy({ $0.count == 0 }) {
                    Text("No data yet")
                        .font(.system(size: 14))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(Array(trend.enumerated()), id: \.element.id) { index, point in
                            // Opacity ramps toward today, so the eye lands on the
                            // most recent bar without a second hue.
                            let fade = 0.35 + 0.65 * (Double(index) / Double(max(trend.count - 1, 1)))

                            UnevenRoundedRectangle(
                                topLeadingRadius: 3, bottomLeadingRadius: 1,
                                bottomTrailingRadius: 1, topTrailingRadius: 3,
                                style: .continuous
                            )
                            .fill(PhosphorTheme.phosphor.opacity(fade))
                            .frame(height: max(2, 56 * Double(point.count) / Double(peak)))
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 56, alignment: .bottom)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("14-day trend, peaking at \(peak) blocks in a day")
                }
            }
        }
    }

    private func trendRange(_ trend: [DashboardViewModel.DailyDataPoint]) -> String {
        guard let first = trend.first?.date, let last = trend.last?.date else { return "" }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(first.formatted(format)) – \(last.formatted(format))"
    }

    // MARK: - Active lists

    private var activeListsRow: some View {
        Button {
            selection = .lists
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PhosphorTheme.phosphor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.enabledListCount) active list\(viewModel.enabledListCount == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PhosphorTheme.ink50)
                    Text("\(viewModel.totalRuleCount.formatted()) rules loaded")
                        .font(PhosphorTheme.data(12, weight: .regular))
                        .foregroundStyle(PhosphorTheme.ink400)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PhosphorTheme.ink900)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PhosphorTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Lists tab")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            PhosphorCard(padding: 28, radius: 22, lit: isFilterRunning) {
                VStack(spacing: 16) {
                    PhosphorMark(size: 72)

                    VStack(spacing: 8) {
                        Text(isFilterRunning ? "Filtering active" : "Filtering not active")
                            .font(.system(size: 26, weight: .bold))
                            .kerning(-0.8)
                            .foregroundStyle(PhosphorTheme.ink50)
                            .multilineTextAlignment(.center)

                        Text(isFilterRunning
                             ? "iOS checks every URL itself and does not tell apps what it blocked, so there are no block counts to show. Your lists are below."
                             : "URL filtering is not running. Turn it on to block ads, trackers and malware across every app.")
                            .font(.system(size: 15))
                            .foregroundStyle(PhosphorTheme.ink300)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !isFilterRunning {
                        Button("Set up filtering") {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        }
                        .buttonStyle(PhosphorPrimaryButtonStyle())
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                PeriodTile(title: "Active lists", count: viewModel.enabledListCount)
                PeriodTile(title: "Rules loaded", count: viewModel.totalRuleCount)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func cardHead(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PhosphorTheme.ink50)
            Spacer()
            Text(trailing)
                .font(PhosphorTheme.data(12, weight: .regular))
                .foregroundStyle(PhosphorTheme.ink400)
        }
    }
}

// MARK: - Period tile

private struct PeriodTile: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(count.formatted())
                .font(PhosphorTheme.data(19))
                .kerning(-0.6)
                .foregroundStyle(PhosphorTheme.phosphor)
                .contentTransition(.numericText())
                .animation(PhosphorTheme.dataAnimation, value: count)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(PhosphorTheme.ink400)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .fill(PhosphorTheme.ink900)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .strokeBorder(PhosphorTheme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(title.lowercased())")
    }
}

#Preview {
    DashboardView(selection: .constant(.dashboard))
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}

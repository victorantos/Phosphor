import Charts
import PhosphorShared
import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var hasAppeared = false

    /// True only when the system filter is actually running.
    private var isFilterRunning: Bool {
        viewModel.filterIsEnabled && viewModel.filterStatus == "Running"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.totalBlocks == 0 {
                    emptyState
                } else {
                    statsContent
                }
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .refreshable { viewModel.load() }
            .onAppear {
                viewModel.load()
                withAnimation(PhosphorTheme.dataAnimation) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            Image(systemName: isFilterRunning ? "shield.checkered" : "shield.slash")
                .font(.system(size: 64))
                .foregroundStyle(isFilterRunning ? PhosphorTheme.accent : .secondary)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(isFilterRunning ? "Filtering Active" : "Filtering Not Active")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isFilterRunning
                    ? "Block stats will appear here as URLs are filtered."
                    : "URL filtering is not running. Enable it to block ads, trackers, and malware across all apps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            // Filter status badge
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.filterStatus)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())

            if !isFilterRunning {
                Button {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                } label: {
                    Label("Set Up Filtering", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhosphorTheme.accent)
                .controlSize(.large)
                .padding(.horizontal, 32)
            }

            statusCard
                .padding(.horizontal)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        switch viewModel.filterStatus {
        case "Running": .green
        case "Starting": .yellow
        case "Stopped": .orange
        default: .red
        }
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 16) {
            heroCard
            periodCards
            categoryChart
            trendChart
            statusCard
        }
        .padding()
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 8) {
            Text("Blocked Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.todayBlocks.formatted())
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(PhosphorTheme.accent)
                .contentTransition(.numericText())
                .animation(PhosphorTheme.dataAnimation, value: viewModel.todayBlocks)

            Text("threats stopped")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.todayBlocks) threats blocked today")
    }

    // MARK: - Period Cards

    private var periodCards: some View {
        HStack(spacing: 12) {
            PeriodCard(title: "This Week", count: viewModel.weekBlocks, icon: "calendar")
            PeriodCard(title: "This Month", count: viewModel.monthBlocks, icon: "calendar.badge.clock")
            PeriodCard(title: "All Time", count: viewModel.totalBlocks, icon: "infinity")
        }
    }

    // MARK: - Category Donut Chart

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .padding(.horizontal, 4)

            if viewModel.categoryBreakdown.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                HStack(spacing: 24) {
                    Chart(viewModel.categoryBreakdown) { point in
                        SectorMark(
                            angle: .value("Count", point.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(colorForCategory(point.category))
                        .cornerRadius(4)
                        .accessibilityLabel("\(point.category.displayName): \(point.count) blocks")
                    }
                    .frame(height: 140)
                    .chartLegend(.hidden)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.categoryBreakdown) { point in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForCategory(point.category))
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                                Text(point.category.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text(point.count.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(point.category.displayName), \(point.count) blocks")
                        }
                    }
                }
                .padding(4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius))
    }

    // MARK: - Trend Line Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("14-Day Trend")
                .font(.headline)
                .padding(.horizontal, 4)

            let trend = viewModel.dailyTrend(days: 14)
            if trend.allSatisfy({ $0.count == 0 }) {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(trend) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Blocks", point.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PhosphorTheme.accent.opacity(0.3), PhosphorTheme.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Blocks", point.count)
                    )
                    .foregroundStyle(PhosphorTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .accessibilityLabel("\(point.date.formatted(.dateTime.month().day())): \(point.count) blocks")
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius))
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.fill")
                .foregroundStyle(PhosphorTheme.accent)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(viewModel.enabledListCount) active list\(viewModel.enabledListCount == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(viewModel.totalRuleCount.formatted()) rules loaded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.enabledListCount) active lists with \(viewModel.totalRuleCount) rules loaded")
    }

    // MARK: - Helpers

    private func colorForCategory(_ category: FilterCategory) -> Color {
        switch category {
        case .ads: PhosphorTheme.accent
        case .trackers: .blue
        case .malware: .red
        case .adultContent: .purple
        }
    }
}

// MARK: - Period Card

private struct PeriodCard: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(count.formatted())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(PhosphorTheme.accent)
                .contentTransition(.numericText())
                .animation(PhosphorTheme.dataAnimation, value: count)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) blocks \(title.lowercased())")
    }
}

#Preview("With Data") {
    DashboardView()
}

#Preview("Empty") {
    DashboardView()
}

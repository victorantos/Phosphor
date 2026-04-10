import Charts
import PhosphorShared
import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.totalBlocks == 0 {
                        emptyHero
                    } else {
                        heroCard
                        periodCards
                        categoryChart
                        trendChart
                    }

                    statusCard
                }
                .padding()
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
            }
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

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 6) {
            Text("Blocked Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.todayBlocks.formatted())
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(PhosphorTheme.accent)
                .contentTransition(.numericText())
                .animation(PhosphorTheme.dataAnimation, value: viewModel.todayBlocks)

            Text("threats stopped")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.todayBlocks) threats blocked today")
    }

    private var emptyHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(PhosphorTheme.accent)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
                .accessibilityHidden(true)

            Text("Phosphor is Active")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Block stats will appear here as URLs are filtered. The on-device Bloom filter handles most lookups instantly.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Phosphor is active. Block stats will appear as URLs are filtered.")
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                HStack(spacing: 20) {
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
                    .frame(width: 120, height: 120)
                    .chartLegend(.hidden)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.categoryBreakdown) { point in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForCategory(point.category))
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                                Text(point.category.displayName)
                                    .font(.caption)
                                Spacer()
                                Text(point.count.formatted())
                                    .font(.caption)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
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
                .frame(height: 160)
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
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.fill")
                .foregroundStyle(PhosphorTheme.accent)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.enabledListCount) active list\(viewModel.enabledListCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(viewModel.totalRuleCount.formatted()) rules loaded")
                    .font(.caption)
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(count.formatted())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(PhosphorTheme.accent)
                .contentTransition(.numericText())
                .animation(PhosphorTheme.dataAnimation, value: count)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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

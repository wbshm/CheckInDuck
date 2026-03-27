import SwiftUI

@MainActor
struct CalendarView: View {
    @ObservedObject private var subscriptionAccess: SubscriptionAccessService
    @StateObject private var viewModel: CalendarViewModel

    init(subscriptionAccess: SubscriptionAccessService) {
        self._subscriptionAccess = ObservedObject(wrappedValue: subscriptionAccess)
        _viewModel = StateObject(
            wrappedValue: CalendarViewModel(subscriptionAccess: subscriptionAccess)
        )
    }

    init(
        viewModel: CalendarViewModel,
        subscriptionAccess: SubscriptionAccessService
    ) {
        self._subscriptionAccess = ObservedObject(wrappedValue: subscriptionAccess)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    dayGrid
                    legendSection
                    freeTierNotice
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(L10n.tr("History")) {
                        HistoryView(subscriptionAccess: subscriptionAccess)
                    }
                }
            }
            .onAppear {
                viewModel.reload()
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .accessibilityLabel(L10n.tr("calendar.previous_month"))

            Spacer()

            Text(viewModel.monthTitle)
                .font(.headline)

            Spacer()

            Button {
                viewModel.moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .accessibilityLabel(L10n.tr("calendar.next_month"))
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(viewModel.dayCells) { cell in
                dayCell(cell)
            }
        }
    }

    private func dayCell(_ cell: CalendarGridCell) -> some View {
        Group {
            if let date = cell.date, let summary = cell.summary {
                let isToday = viewModel.isToday(date)
                VStack(spacing: 6) {
                    Text(dayNumberText(for: date))
                        .font(.subheadline.weight(isToday ? .semibold : .regular))
                        .foregroundStyle(.primary)

                    if summary.isRestricted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L10n.tr("calendar.restricted_day"))
                    } else if !summary.statusIndicators.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(summary.statusIndicators, id: \.rawValue) { status in
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.vertical, 6)
                .background(backgroundColor(for: summary))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Color.clear
                    .frame(height: 54)
            }
        }
    }

    private var legendSection: some View {
        HStack(spacing: 14) {
            legendItem(status: .completed)
            legendItem(status: .pending)
            legendItem(status: .missed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var freeTierNotice: some View {
        if let lookbackDays = subscriptionAccess.historyLookbackDays() {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.format("history.free_tier_window", lookbackDays))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink("Upgrade to Premium") {
                    UpgradeView(
                        subscriptionAccess: subscriptionAccess,
                        entryPoint: .historyLimit
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func legendItem(status: DailyTaskStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 8, height: 8)
            Text(status.localizedTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dayNumberText(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private func backgroundColor(for summary: CalendarDaySummary) -> Color {
        if summary.isRestricted {
            return .gray.opacity(0.10)
        }

        switch summary.primaryStatus {
        case .completed:
            return .green.opacity(0.18)
        case .pending:
            return .orange.opacity(0.18)
        case .missed:
            return .red.opacity(0.20)
        case nil:
            return .gray.opacity(0.08)
        }
    }

    private func statusColor(for status: DailyTaskStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .red
        }
    }
}

#Preview {
    CalendarView(subscriptionAccess: SubscriptionAccessService())
}

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
    private let metricColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        monthInsightsSection
                        monthHeader
                        weekdayHeader
                        dayGrid
                        legendSection
                        dayDetailSection
                        freeTierNotice
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
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
            monthSwitchButton(
                systemImage: "chevron.left",
                isEnabled: viewModel.canMoveToPreviousMonth,
                action: { viewModel.moveMonth(by: -1) },
                accessibilityLabel: L10n.tr("calendar.previous_month")
            )

            Spacer()

            Text(viewModel.monthTitle)
                .font(.headline)

            Spacer()

            monthSwitchButton(
                systemImage: "chevron.right",
                isEnabled: viewModel.canMoveToNextMonth,
                action: { viewModel.moveMonth(by: 1) },
                accessibilityLabel: L10n.tr("calendar.next_month")
            )
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
                let isSelected = viewModel.isSelected(date)
                let isInteractive = summary.hasData
                if isInteractive {
                    Button {
                        viewModel.selectDate(date)
                    } label: {
                        dayCellContent(
                            summary: summary,
                            date: date,
                            isToday: isToday,
                            isSelected: isSelected,
                            isInteractive: isInteractive
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    dayCellContent(
                        summary: summary,
                        date: date,
                        isToday: isToday,
                        isSelected: isSelected,
                        isInteractive: isInteractive
                    )
                }
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

    private var monthInsightsSection: some View {
        let insights = viewModel.monthInsights

        return sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr("calendar.monthly_summary.title"))
                    .font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(insights.completedCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(L10n.tr("calendar.monthly_summary.completed_unit"))
                        .font(.title3.weight(.semibold))
                }

                Text(monthlySubtitle(for: insights))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: metricColumns, spacing: 8) {
                    metricItem(
                        title: L10n.tr("calendar.monthly_summary.metric.active_days"),
                        value: L10n.format("calendar.metric.days_value", insights.activeDays),
                        color: .blue
                    )
                    metricItem(
                        title: L10n.tr("calendar.monthly_summary.metric.completed"),
                        value: "\(insights.completedCount)",
                        color: .green
                    )
                    metricItem(
                        title: L10n.tr("calendar.monthly_summary.metric.pending"),
                        value: "\(insights.pendingCount)",
                        color: .orange
                    )
                    metricItem(
                        title: L10n.tr("calendar.monthly_summary.metric.missed"),
                        value: "\(insights.missedCount)",
                        color: .red
                    )
                }
            }
        }
    }

    private var dayDetailSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr("calendar.day_detail.title"))
                    .font(.headline)

                if let selectedDate = viewModel.selectedDate {
                    selectedDayContent(for: selectedDate)
                } else {
                    Text(L10n.tr("calendar.day_detail.placeholder"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func monthSwitchButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void,
        accessibilityLabel: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 32, height: 32)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0)
        .accessibilityLabel(accessibilityLabel)
    }

    private func dayCellContent(
        summary: CalendarDaySummary,
        date: Date,
        isToday: Bool,
        isSelected: Bool,
        isInteractive: Bool
    ) -> some View {
        VStack(spacing: 6) {
            Text(dayNumberText(for: date))
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isInteractive ? .primary : .secondary)

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
                .stroke(selectionBorderColor(isToday: isToday, isSelected: isSelected), lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func selectedDayContent(for selectedDate: Date) -> some View {
        let summary = viewModel.summary(for: selectedDate)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))

                if viewModel.isToday(selectedDate) {
                    Text(L10n.tr("calendar.day_detail.today"))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.10))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                statusCountChip(
                    title: L10n.tr("status.completed"),
                    count: summary.completedCount,
                    color: .green
                )
                statusCountChip(
                    title: L10n.tr("status.pending"),
                    count: summary.pendingCount,
                    color: .orange
                )
                statusCountChip(
                    title: L10n.tr("status.missed"),
                    count: summary.missedCount,
                    color: .red
                )
            }

            if let detail = viewModel.dayDetail(for: selectedDate) {
                VStack(spacing: 0) {
                    ForEach(Array(detail.taskDetails.enumerated()), id: \.element.id) { index, task in
                        dayDetailRow(task)

                        if index < detail.taskDetails.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                emptyDetailState
            }
        }
    }

    private func dayDetailRow(_ task: CalendarDayTaskDetail) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(statusColor(for: task.status))
                .frame(width: 6, height: 34)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    Text(task.taskName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(task.status.localizedTitle)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(for: task.status).opacity(0.14))
                        .foregroundStyle(statusColor(for: task.status))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    detailMetaTag(
                        text: viewModel.completionSourceText(for: task.completionSource)
                            ?? L10n.tr("history.source.not_completed"),
                        systemImage: task.completionSource == .manual ? "hand.tap.fill" : task.completionSource == .appUsageThreshold ? "app.badge.checkmark" : "minus.circle"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func metricItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusCountChip(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(count)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var emptyDetailState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("calendar.day_detail.empty"))
                .font(.subheadline.weight(.medium))
            Text(L10n.tr("calendar.day_detail.empty_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailMetaTag(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(uiColor: .systemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
            )
    }

    private func monthlySubtitle(for insights: CalendarMonthInsights) -> String {
        if let completionRate = insights.completionRate {
            let ratePercent = Int((completionRate * 100).rounded())
            return L10n.format(
                "calendar.monthly_summary.subtitle_with_rate",
                insights.activeDays,
                ratePercent
            )
        }
        return L10n.format("calendar.monthly_summary.subtitle_no_rate", insights.activeDays)
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

    private func selectionBorderColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.8)
        }
        if isToday {
            return Color.accentColor.opacity(0.45)
        }
        return .clear
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

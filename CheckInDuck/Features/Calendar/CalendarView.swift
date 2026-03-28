import SwiftUI

@MainActor
struct CalendarView: View {
    @ObservedObject private var subscriptionAccess: SubscriptionAccessService
    @StateObject private var viewModel: CalendarViewModel
    @State private var noteDraft = ""
    @State private var isPresentingNoteEditor = false

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
                        calendarSection
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
                syncNoteDraft()
            }
            .onChange(of: viewModel.selectedDate) { _ in
                syncNoteDraft()
            }
            .sheet(isPresented: $isPresentingNoteEditor) {
                noteEditorSheet
            }
        }
    }

    private var calendarSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                monthHeader
                weekdayHeader
                dayGrid
                legendSection
            }
        }
    }

    private var monthHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(viewModel.monthTitle)
                .font(.headline)

            Spacer()

            HStack(spacing: 8) {
                monthSwitchButton(
                    systemImage: "chevron.left",
                    isEnabled: viewModel.canMoveToPreviousMonth,
                    action: { viewModel.moveMonth(by: -1) },
                    accessibilityLabel: L10n.tr("calendar.previous_month")
                )

                monthSwitchButton(
                    systemImage: "chevron.right",
                    isEnabled: viewModel.canMoveToNextMonth,
                    action: { viewModel.moveMonth(by: 1) },
                    accessibilityLabel: L10n.tr("calendar.next_month")
                )
            }
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
                let isInteractive = summary.hasContent
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
        .padding(.top, 2)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.10), lineWidth: 1)
        )
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
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .systemBackground))
                .clipShape(Circle())
        }
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? .primary : .secondary)
        .opacity(isEnabled ? 1 : 0.45)
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
                .foregroundStyle(dayNumberColor(for: summary, isToday: isToday, isSelected: isSelected))

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
        .background(dayCellBackgroundColor(for: summary, isSelected: isSelected))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    dayCellBorderColor(
                        summary: summary,
                        isToday: isToday,
                        isSelected: isSelected,
                        isInteractive: isInteractive
                    ),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if summary.hasNote {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 1.5)
                    )
                    .padding(.top, 7)
                    .padding(.trailing, 7)
                    .accessibilityLabel(L10n.tr("calendar.note.marker"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func selectedDayContent(for selectedDate: Date) -> some View {
        let detail = viewModel.dayDetail(for: selectedDate)
        let summary = detail?.summary ?? viewModel.summary(for: selectedDate)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                if viewModel.isToday(selectedDate) {
                    Text(L10n.tr("calendar.day_detail.today"))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.10))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Spacer()
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

            if let detail, !detail.taskDetails.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(detail.taskDetails.enumerated()), id: \.element.id) { index, task in
                        dayDetailRow(task)

                        if index < detail.taskDetails.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                emptyDetailState
            }

            noteEditorSection(for: selectedDate)
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
                }

                HStack(spacing: 8) {
                    statusBadge(for: task.status)
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

    private func statusBadge(for status: DailyTaskStatus) -> some View {
        Text(status.localizedTitle)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: status).opacity(0.14))
            .foregroundStyle(statusColor(for: status))
            .clipShape(Capsule())
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func noteEditorSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("calendar.note.title"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let savedNote = viewModel.noteText(for: date), !savedNote.isEmpty {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(L10n.tr("calendar.note.marker"))
                }
            }

            Button {
                syncNoteDraft()
                isPresentingNoteEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    if let savedNote = viewModel.noteText(for: date), !savedNote.isEmpty {
                        Text(savedNote)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(L10n.tr("calendar.note.placeholder"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Spacer()
                        Label(
                            noteEntryActionTitle(for: date),
                            systemImage: "square.and.pencil"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var noteEditorSheet: some View {
        if let selectedDate = viewModel.selectedDate {
            NavigationStack {
                VStack(spacing: 0) {
                    TextEditor(text: $noteDraft)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(16)

                    Spacer(minLength: 0)
                }
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(L10n.tr("calendar.note.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            syncNoteDraft()
                            isPresentingNoteEditor = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveNote(for: selectedDate)
                            isPresentingNoteEditor = false
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(!hasUnsavedNoteChanges(for: selectedDate))
                        .accessibilityLabel(L10n.tr("calendar.note.save"))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !normalizedNoteText(viewModel.noteText(for: selectedDate) ?? "").isEmpty {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            noteDraft = ""
                            saveNote(for: selectedDate)
                            isPresentingNoteEditor = false
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel(L10n.tr("calendar.note.remove"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .presentationDetents([.medium, .large])
        }
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemBackground))
        .clipShape(Capsule())
    }

    private func dayNumberText(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private func dayNumberColor(
        for summary: CalendarDaySummary,
        isToday: Bool,
        isSelected: Bool
    ) -> Color {
        if summary.isRestricted {
            return .secondary
        }
        if isSelected {
            return .accentColor
        }
        if isToday {
            return Color.accentColor.opacity(0.9)
        }
        return .primary
    }

    private func dayCellBackgroundColor(for summary: CalendarDaySummary, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.10)
        }

        if summary.isRestricted {
            return Color(uiColor: .tertiarySystemFill)
        }

        switch summary.primaryStatus {
        case .completed:
            return .green.opacity(0.18)
        case .pending:
            return .orange.opacity(0.18)
        case .missed:
            return .red.opacity(0.20)
        case nil:
            return Color(uiColor: .systemBackground)
        }
    }

    private func dayCellBorderColor(
        summary: CalendarDaySummary,
        isToday: Bool,
        isSelected: Bool,
        isInteractive: Bool
    ) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.8)
        }
        if isToday {
            return Color.accentColor.opacity(0.45)
        }
        if summary.isRestricted {
            return Color(uiColor: .separator).opacity(0.10)
        }
        return isInteractive
            ? Color(uiColor: .separator).opacity(0.14)
            : Color(uiColor: .separator).opacity(0.08)
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

    private func syncNoteDraft() {
        guard let selectedDate = viewModel.selectedDate else {
            noteDraft = ""
            return
        }
        noteDraft = viewModel.noteText(for: selectedDate) ?? ""
    }

    private func saveNote(for date: Date) {
        viewModel.updateNote(noteDraft, for: date)
        noteDraft = viewModel.noteText(for: date) ?? ""
    }

    private func hasUnsavedNoteChanges(for date: Date) -> Bool {
        normalizedNoteText(noteDraft) != normalizedNoteText(viewModel.noteText(for: date) ?? "")
    }

    private func noteEntryActionTitle(for date: Date) -> String {
        let hasSavedNote = !normalizedNoteText(viewModel.noteText(for: date) ?? "").isEmpty
        return hasSavedNote
            ? L10n.tr("calendar.note.edit")
            : L10n.tr("calendar.note.add")
    }

    private func normalizedNoteText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    CalendarView(subscriptionAccess: SubscriptionAccessService())
}

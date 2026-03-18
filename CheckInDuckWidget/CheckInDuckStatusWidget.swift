import SwiftUI
import WidgetKit

struct CheckInDuckStatusWidget: Widget {
    private let kind = "CheckInDuckStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CheckInDuckStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.tr("widget.configuration.display_name"))
        .description(WidgetL10n.tr("widget.configuration.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CheckInDuckStatusEntry {
        CheckInDuckStatusEntry(
            date: .now,
            snapshot: .placeholder
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInDuckStatusEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInDuckStatusEntry>) -> Void) {
        let currentDate = Date()
        let entry = makeEntry(at: currentDate)
        let refreshDate = min(
            Calendar.current.startOfDay(for: currentDate).addingTimeInterval(24 * 60 * 60),
            currentDate.addingTimeInterval(15 * 60)
        )

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func makeEntry(at date: Date) -> CheckInDuckStatusEntry {
        CheckInDuckStatusEntry(
            date: date,
            snapshot: WidgetDataLoader(calendar: .current).load(now: date)
        )
    }
}

private struct CheckInDuckStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTodaySnapshot
}

private struct CheckInDuckStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: CheckInDuckStatusEntry

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 17.0, *) {
                content
                    .containerBackground(for: .widget) {
                        widgetBackground
                    }
            } else {
                content
                    .background(widgetBackground)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            mediumContent
        default:
            smallContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            smallHeader

            if entry.snapshot.tasks.isEmpty {
                emptyState
            } else {
                smallLayout
            }
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumContent: some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 0 // Adjust the left/right outer padding for the whole 2x4 widget.
            let verticalInset: CGFloat = 0 // Adjust the top/bottom outer padding for the whole 2x4 widget.
            let columnSpacing: CGFloat = 16 // Adjust the gap between the overview column and the task list column.
            let contentWidth = max(proxy.size.width - (horizontalInset * 2) - columnSpacing, 0)
            let overviewWidth = contentWidth / 3 // Keep the medium widget close to a 1:2 left/right column split.

            HStack(alignment: .top, spacing: columnSpacing) {
                mediumOverview
                    .frame(width: overviewWidth, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .leading)

                if entry.snapshot.tasks.isEmpty {
                    emptyState
                } else {
                    mediumLayout
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var mediumHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.13, blue: 0.18))

                    Text(summaryText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color(red: 0.40, green: 0.45, blue: 0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(entry.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(red: 0.47, green: 0.53, blue: 0.60))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.8))
                    )
            }

            HStack(spacing: 8) {
                StatusPill(label: "Pending", count: entry.snapshot.pendingCount, color: .pending)
                StatusPill(label: "Done", count: entry.snapshot.completedCount, color: .completed)
                StatusPill(label: "Missed", count: entry.snapshot.missedCount, color: .missed)
            }
        }
    }

    private var smallHeader: some View {
        // 小尺寸小组件头部（应用名 + 任务总数）
        HStack(alignment: .firstTextBaseline) { // 按文本首行基线对齐，保证文字排版整齐
            // 应用名称文本
            Text("CheckInDuck")
                .font(.system(size: 15, weight: .semibold)) // 字体大小15，半粗体
                .foregroundStyle(accentTextColor) // 蓝色文字
                .lineLimit(1) // 限制单行显示
                .minimumScaleFactor(0.72) // 文字最小缩放比例（防止文字溢出）
            Spacer(minLength: 4) // 最小间距4的空白分隔，推挤右侧数字到右边
            // 今日任务总数文本
            Text("\(entry.snapshot.tasks.count)")
                .font(.system(size: 22, weight: .bold)) // 字体大小22，粗体
                .foregroundStyle(primaryTextColor) // 深浅色模式下都可读的主文字颜色
        }
        .padding(.top, 10)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(smallListTasks.enumerated()), id: \.element.id) { _, task in
                HStack(spacing: 12) {
                    SmallTaskBullet(status: task.status)

                    Text(task.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(1)

                    Spacer(minLength: 3)

                    SmallTrailingStatus(status: task.status)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumOverview: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(accentTextColor)
                    .frame(width: 30, height: 30) // Adjust the top-left icon size.

                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 1) // Adjust the top breathing room above the overview icon.

            Spacer(minLength: 6) // Adjust the flexible gap between the icon area and the bottom summary area.

            Text("\(entry.snapshot.tasks.count)")
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)

            Text("CheckInDuck")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(accentTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(mediumOverviewDetailText)
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.top, 2) // Adjust the gap between the title and the compact status summary.
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 4) { // Adjust the vertical spacing between list rows on the right side.
            ForEach(Array(mediumListTasks.enumerated()), id: \.element.id) { _, task in
                MediumTaskRow(task: task)
                    .frame(height: 31, alignment: .top) // Adjust the per-row height for the right-side task list.
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 14 : 10) {
            // HStack(spacing: 10) {
            //     Image(systemName: "checklist")
            //         .font(.system(size: family == .systemSmall ? 20 : 16, weight: .semibold))
            //         .foregroundStyle(family == .systemSmall ? Color(red: 0.12, green: 0.60, blue: 0.93) : Color(red: 0.19, green: 0.53, blue: 0.38))
            //         .frame(width: 32, height: 32)

            //     Text("No active tasks")
            //         .font(.system(family == .systemSmall ? .subheadline : .headline, design: .rounded).weight(.semibold))
            //         .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.19))
            // }

            // Text(family == .systemSmall ? "Add or enable a task to show today's progress." : "Add or enable a task in CheckInDuck to see today's progress here.")
            //     .font(.system(family == .systemSmall ? .caption2 : .caption, design: .rounded))
            //     .foregroundStyle(Color(red: 0.39, green: 0.44, blue: 0.51))
            //     .lineLimit(family == .systemSmall ? 2 : 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var widgetBackground: some View {
        widgetBackgroundColor
    }

    private var accentTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.37, green: 0.74, blue: 1.00)
            : Color(red: 0.12, green: 0.60, blue: 0.93)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.97, blue: 0.98)
            : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.64, green: 0.68, blue: 0.74)
            : Color(red: 0.42, green: 0.46, blue: 0.52)
    }

    private var widgetBackgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.14, blue: 0.16)
            : Color(red: 0.985, green: 0.985, blue: 0.982)
    }

    private var summaryText: String {
        if entry.snapshot.tasks.isEmpty {
            return "Nothing scheduled"
        }

        if entry.snapshot.missedCount > 0 {
            return "\(entry.snapshot.pendingCount) pending, \(entry.snapshot.missedCount) missed"
        }

        return "\(entry.snapshot.pendingCount) pending, \(entry.snapshot.completedCount) done"
    }

    private var smallListTasks: [WidgetTaskStatusSnapshot] {
        let prioritized = entry.snapshot.tasks.filter { $0.status != .completed }
        if prioritized.isEmpty {
            return Array(entry.snapshot.tasks.prefix(3))
        }
        return Array(prioritized.prefix(3))
    }

    private var mediumListTasks: [WidgetTaskStatusSnapshot] {
        let prioritized = entry.snapshot.tasks.filter { $0.status != .completed }
        let completed = entry.snapshot.tasks.filter { $0.status == .completed }
        return Array((prioritized + completed).prefix(4))
    }

    private var mediumOverviewDetailText: String {
        if entry.snapshot.missedCount > 0 {
            return WidgetL10n.format("widget.overview.missed", entry.snapshot.missedCount)
        }

        if entry.snapshot.pendingCount > 0 {
            return WidgetL10n.format("widget.overview.pending", entry.snapshot.pendingCount)
        }

        return WidgetL10n.format("widget.overview.done", entry.snapshot.completedCount)
    }

    private var detailText: String {
        if entry.snapshot.completedCount == entry.snapshot.tasks.count {
            return WidgetL10n.tr("widget.detail.complete")
        }

        if entry.snapshot.pendingCount > 0 {
            return WidgetL10n.format("widget.detail.pending", entry.snapshot.pendingCount)
        }

        return WidgetL10n.tr("widget.detail.missed")
    }

    private func taskSubtitle(for task: WidgetTaskStatusSnapshot) -> String {
        switch task.status {
        case .pending:
            return "Due by \(task.deadlineText)"
        case .completed:
            return "Completed today"
        case .missed:
            return "Missed at \(task.deadlineText)"
        }
    }
}

private enum WidgetL10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: NSLocalizedString(key, comment: ""),
            locale: Locale.current,
            arguments: arguments
        )
    }
}

private struct MediumTaskRow: View {
    let task: WidgetTaskStatusSnapshot

    var body: some View {
        HStack(spacing: 10) { // Adjust the horizontal spacing between the bullet, title, and trailing status icon.
            SmallTaskBullet(status: task.status)

            Text(task.title)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6) // Adjust the minimum separation between title text and trailing status icon.

            SmallTrailingStatus(status: task.status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OverviewStat: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) { // Adjust the internal spacing for each compact stat row in the left column.
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(count)")
                .font(.system(size: 9.5, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
        }
    }
}

private struct SmallTaskBullet: View {
    let status: WidgetTaskStatus

    var body: some View {
        ZStack {
            Circle()
                .stroke(bulletColor, lineWidth: 1.6)
                .background(
                    Circle()
                        .fill(status == .completed ? bulletColor : .clear)
                )

            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
    }

    private var bulletColor: Color {
        switch status {
        case .pending:
            return Color(.systemGray3)
        case .completed:
            return Color(red: 0.20, green: 0.69, blue: 0.45)
        case .missed:
            return Color(red: 0.88, green: 0.34, blue: 0.28)
        }
    }
}

private struct SmallTrailingStatus: View {
    let status: WidgetTaskStatus

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(symbolColor)
            .frame(width: 12, height: 12)
    }

    private var symbolName: String {
        switch status {
        case .pending:
            return "clock.arrow.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "exclamationmark.circle"
        }
    }

    private var symbolColor: Color {
        switch status {
        case .pending:
            return Color(.systemGray2)
        case .completed:
            return Color(red: 0.20, green: 0.69, blue: 0.45)
        case .missed:
            return Color(red: 0.88, green: 0.34, blue: 0.28)
        }
    }
}

private struct StatusPill: View {
    let label: String
    let count: Int
    let color: WidgetStatusColor

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.fill)
                .frame(width: 7, height: 7)

            Text("\(count)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color(red: 0.16, green: 0.19, blue: 0.23))

            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Color(red: 0.43, green: 0.48, blue: 0.55))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.84))
        )
    }
}

private struct StatusDot: View {
    let status: WidgetTaskStatus

    var body: some View {
        let palette = WidgetStatusColor(status: status)

        ZStack {
            Circle()
                .fill(palette.fill.opacity(status == .completed ? 0.95 : 0.16))

            Circle()
                .stroke(palette.fill, lineWidth: status == .completed ? 0 : 1.5)

            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct WidgetCardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.00),
                    Color(red: 0.94, green: 0.96, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: 120, height: 120)
                .offset(x: 70, y: -56)

            Circle()
                .fill(Color(red: 0.89, green: 0.95, blue: 0.93).opacity(0.45))
                .frame(width: 110, height: 110)
                .offset(x: -84, y: 70)
        }
    }
}

private struct WidgetStatusColor {
    let fill: Color

    private init(fill: Color) {
        self.fill = fill
    }

    static let pending = WidgetStatusColor(fill: Color(red: 0.95, green: 0.62, blue: 0.16))
    static let completed = WidgetStatusColor(fill: Color(red: 0.20, green: 0.69, blue: 0.45))
    static let missed = WidgetStatusColor(fill: Color(red: 0.88, green: 0.34, blue: 0.28))

    init(status: WidgetTaskStatus) {
        switch status {
        case .pending:
            self = .pending
        case .completed:
            self = .completed
        case .missed:
            self = .missed
        }
    }
}

private struct WidgetDataLoader {
    private let calendar: Calendar
    private let decoder = JSONDecoder()

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func load(now: Date) -> WidgetTodaySnapshot {
        let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName)
        let tasks = load([WidgetHabitTask].self, key: WidgetSharedStorageKey.tasks, defaults: defaults) ?? []
        let records = load([WidgetDailyRecord].self, key: WidgetSharedStorageKey.records, defaults: defaults) ?? []

        return WidgetSnapshotBuilder(calendar: calendar).build(tasks: tasks, records: records, now: now)
    }

    private func load<Value: Decodable>(
        _ type: Value.Type,
        key: String,
        defaults: UserDefaults?
    ) -> Value? {
        guard let data = defaults?.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(Value.self, from: data)
    }
}

private enum WidgetSharedStorageKey {
    static let tasks = "habit_tasks_v1"
    static let records = "daily_records_v1"
}

private enum WidgetAppGroup {
    static let suiteName = "group.com.wang.CheckInDuck"
}

private struct WidgetSnapshotBuilder {
    private let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func build(
        tasks: [WidgetHabitTask],
        records: [WidgetDailyRecord],
        now: Date
    ) -> WidgetTodaySnapshot {
        let snapshots = tasks
            .filter(\.isEnabled)
            .map { task in
                WidgetTaskStatusSnapshot(
                    id: task.id,
                    title: task.name,
                    status: status(for: task, records: records, now: now),
                    deadlineText: task.deadline.displayText
                )
            }
            .sorted(by: sortSnapshots)

        return WidgetTodaySnapshot(
            pendingCount: snapshots.filter { $0.status == .pending }.count,
            completedCount: snapshots.filter { $0.status == .completed }.count,
            missedCount: snapshots.filter { $0.status == .missed }.count,
            tasks: snapshots
        )
    }

    private func status(
        for task: WidgetHabitTask,
        records: [WidgetDailyRecord],
        now: Date
    ) -> WidgetTaskStatus {
        if let record = records.first(where: { $0.taskId == task.id && calendar.isDate($0.date, inSameDayAs: now) }) {
            return record.status
        }

        return isPastDeadline(task: task, now: now) ? .missed : .pending
    }

    private func isPastDeadline(task: WidgetHabitTask, now: Date) -> Bool {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = task.deadline.hour
        components.minute = task.deadline.minute

        guard let deadlineDate = calendar.date(from: components) else {
            return false
        }

        return now >= deadlineDate
    }

    private func sortSnapshots(
        _ lhs: WidgetTaskStatusSnapshot,
        _ rhs: WidgetTaskStatusSnapshot
    ) -> Bool {
        if statusPriority(lhs.status) != statusPriority(rhs.status) {
            return statusPriority(lhs.status) < statusPriority(rhs.status)
        }

        if lhs.deadlineText != rhs.deadlineText {
            return lhs.deadlineText < rhs.deadlineText
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func statusPriority(_ status: WidgetTaskStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .missed:
            return 1
        case .completed:
            return 2
        }
    }
}

private struct WidgetTodaySnapshot {
    let pendingCount: Int
    let completedCount: Int
    let missedCount: Int
    let tasks: [WidgetTaskStatusSnapshot]

    static let placeholder = WidgetTodaySnapshot(
        pendingCount: 1,
        completedCount: 1,
        missedCount: 0,
        tasks: [
            WidgetTaskStatusSnapshot(
                id: UUID(),
                title: "Read 20 minutes",
                status: .pending,
                deadlineText: "20:00"
            ),
            WidgetTaskStatusSnapshot(
                id: UUID(),
                title: "Standup notes",
                status: .completed,
                deadlineText: "09:00"
            ),
        ]
    )
}

private struct WidgetTaskStatusSnapshot: Identifiable {
    let id: UUID
    let title: String
    let status: WidgetTaskStatus
    let deadlineText: String
}

private enum WidgetTaskStatus: String, Codable {
    case pending
    case completed
    case missed
}

private struct WidgetHabitTask: Identifiable, Decodable {
    let id: UUID
    let name: String
    let deadline: WidgetDailyDeadline
    let isEnabled: Bool
}

private struct WidgetDailyDeadline: Decodable {
    let hour: Int
    let minute: Int

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

private struct WidgetDailyRecord: Decodable {
    let id: UUID
    let taskId: UUID
    let date: Date
    let status: WidgetTaskStatus

    private enum CodingKeys: String, CodingKey {
        case id
        case taskId
        case taskID
        case date
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskId =
            try container.decodeIfPresent(UUID.self, forKey: .taskId) ??
            container.decode(UUID.self, forKey: .taskID)
        date = try container.decode(Date.self, forKey: .date)
        status = try container.decode(WidgetTaskStatus.self, forKey: .status)
    }
}

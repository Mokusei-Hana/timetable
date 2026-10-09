import SwiftUI

private enum SheetRoute: Identifiable {
    case settings, weeks, today
    case course(Course, Int)
    var id: String {
        switch self {
        case .settings: return "settings"
        case .weeks: return "weeks"
        case .today: return "today"
        case .course(let course, let week): return "\(course.id)-\(week)"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("showWeekend") private var showWeekend = false
    @State private var route: SheetRoute?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.hasData {
                            todayCard(context.date)
                            weekControls
                            if store.doc.courses.allSatisfy({ !$0.isActive(inWeek: store.week) }) {
                                Label("这一周没有课程，留些时间给自己。", systemImage: "sun.max")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .padding(.horizontal, Design.inset)
                            }
                            WeekGrid(showWeekend: showWeekend) { course in
                                route = .course(course, store.week)
                            }
                            Text("左右滑动查看各天 · 轻点课程查看详情")
                                .font(.footnote).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        } else {
                            ContentUnavailableView {
                                Label("还没有课表", systemImage: "calendar.badge.exclamationmark")
                            } description: {
                                Text("自带数据未能读取。导入一份课表文件，即可开始安排这一学期。")
                            } actions: {
                                Button("导入课表") { route = .settings }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(.vertical, Design.inset)
                }
                .onChange(of: context.date) { _, date in store.refreshToday(date) }
            }
            .background(Design.background)
            .navigationTitle("课程表")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { route = .settings } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("数据管理")
                }
            }
            .sheet(item: $route) { sheet in
                NavigationStack {
                    Group {
                        switch sheet {
                        case .settings: SettingsView()
                        case .weeks: WeekPickerView()
                        case .today: TodayAgendaView()
                        case .course(let course, let week): CourseDetailView(course: course, week: week)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { route = nil }
                        }
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .timetableAlert(store, enabled: route == nil)
        }
        .tint(Design.accent(dark: colorScheme == .dark))
        .accentColor(Design.accent(dark: colorScheme == .dark))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshToday() }
        }
    }

    private func todayCard(_ now: Date) -> some View {
        let today = TodaySnapshot(doc: store.doc, now: now)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今天").font(.title2.bold())
                    Text(now, format: .dateTime.month().day().weekday(.wide))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let week = today.week {
                    Text("第 \(week) 周 · \(today.lessons.count) 节课")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            if let focus = today.focus, let week = today.week {
                Button { route = .course(focus, week) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.accentColor).frame(width: 4)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(today.status).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                            Text(focus.name).font(.title3.bold()).foregroundStyle(.primary)
                                .lineLimit(2).multilineTextAlignment(.leading)
                            Text("\(focus.time) · \(focus.shortLocation)")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .lineLimit(2).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(today.emptyTitle).font(.title3.weight(.semibold))
                Text(today.week == nil ? "仍可在下方浏览整个学期的安排。" : "让学习与生活，都有从容的节奏。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !today.lessons.isEmpty {
                Button { route = .today } label: {
                    HStack {
                        Text("查看今日安排")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(Design.inset)
        .background(Design.surface, in: RoundedRectangle(cornerRadius: Design.radius))
        .padding(.horizontal, Design.inset)
    }

    private var weekControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button { route = .weeks } label: {
                    HStack(spacing: 8) {
                        Text("第 \(store.week) 周").font(.title2.bold()).foregroundStyle(.primary)
                        Image(systemName: "chevron.down").font(.caption.bold())
                    }.frame(minHeight: 44)
                }
                .accessibilityLabel("第 \(store.week) 周，选择周次")
                Spacer(minLength: 0)
                Button { store.jumpToToday() } label: {
                    Text(store.doc.week(containing: Date()) == nil ? "当前" : "本周")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
                Button { turnWeek(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(store.week == 1).accessibilityLabel("上一周")
                Button { turnWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(store.week == store.totalWeeks).accessibilityLabel("下一周")
            }
            if let start = store.doc.date(day: 1, week: store.week),
               let end = store.doc.date(day: 7, week: store.week) {
                HStack(spacing: 4) {
                    Text(start, format: .dateTime.month().day())
                    Text("—")
                    Text(end, format: .dateTime.month().day())
                    Spacer()
                    Text(store.doc.term).lineLimit(1)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Picker("显示天数", selection: $showWeekend) {
                Text("五天").tag(false)
                Text("七天").tag(true)
            }.pickerStyle(.segmented)
            if !showWeekend && store.doc.hasWeekendCourse(week: store.week) {
                Button { showWeekend = true } label: {
                    Label("周末有课 · 展开七天", systemImage: "calendar.badge.clock")
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, Design.inset)
    }

    private func turnWeek(_ delta: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { store.changeWeek(by: delta) }
    }
}

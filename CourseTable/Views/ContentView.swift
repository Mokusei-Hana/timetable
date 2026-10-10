import SwiftUI

private enum SheetRoute: Identifiable {
    case settings, weeks, today
    case course(Course, Int, String)
    case conflict(CourseCluster, Int)
    var id: String {
        switch self {
        case .settings: return "settings"
        case .weeks: return "weeks"
        case .today: return "today"
        case .course(let course, let week, _): return "\(course.id)-\(week)"
        case .conflict(let cluster, let week): return "conflict-\(cluster.id)-\(week)"
        }
    }
    var zoomSourceID: String? {
        if case .course(_, _, let source) = self { return source }
        return nil
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("scheduleViewMode") private var mode: ScheduleViewMode = .cards
    @State private var route: SheetRoute?
    @Namespace private var courseTransitions

    var body: some View {
        NavigationStack {
            GeometryReader { container in
                if store.hasData {
                    let width = max(1, container.size.width - 24)
                    // 短容器或辅助功能大字体时，整页只有一个滚动容器，避免顶部挤掉课表。
                    if container.size.height < 460 || dynamicType.isAccessibilitySize {
                        ScrollView(.vertical) {
                            VStack(spacing: 10) {
                                header
                                schedule(size: CGSize(width: width, height: max(240, container.size.height / 2)), scrolls: false)
                            }.padding(.horizontal, 12).padding(.vertical, 8)
                        }
                    } else {
                        VStack(spacing: 10) {
                            header.fixedSize(horizontal: false, vertical: true)
                            GeometryReader { remaining in
                                schedule(size: remaining.size, scrolls: true)
                            }
                        }.padding(.horizontal, 12).padding(.vertical, 8)
                    }
                } else if store.isBusy {
                    ProgressView("正在读取课表…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("还没有课表", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("自带数据未能读取。导入一份课表文件，即可开始安排这一学期。")
                    } actions: {
                        Button("导入课表") { route = .settings }.adaptiveActionStyle(prominent: true)
                    }
                }
            }
            .animation(reduceMotion ? nil : InterfaceMotion.content, value: store.hasData)
            .background(Design.background)
            .navigationTitle("课程表")
            .navigationBarTitleDisplayMode(.inline)
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
                        case .course(let course, let week, _): CourseDetailView(course: course, week: week)
                        case .conflict(let cluster, let week): ConflictCoursesView(cluster: cluster, week: week)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("完成") { route = nil } }
                    }
                }
                .presentationDragIndicator(.visible)
                .courseZoomDestination(sheet.zoomSourceID, in: courseTransitions)
                .respectMotionPreference()
            }
            .timetableAlert(store, enabled: route == nil)
        }
        .tint(Design.accent(dark: colorScheme == .dark))
        .accentColor(Design.accent(dark: colorScheme == .dark))
        .respectMotionPreference()
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshToday() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            TodaySummaryView(schedule: store.todaySchedule, transitionNamespace: courseTransitions,
                             openCourse: { route = .course($0, $1, $2) },
                             openAgenda: { route = .today }, tick: { store.refreshToday($0) })
            weekControls
            ViewModeSwitcher(selection: $mode)
            if store.presentation.count == 0 {
                Text("这一周没有课程").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var weekControls: some View {
        VStack(spacing: 2) {
            WeekNavigationView(week: store.week, totalWeeks: store.totalWeeks,
                               currentWeek: store.todaySchedule.week ?? (store.todaySchedule.beforeTerm ? 1 : store.totalWeeks),
                               inTerm: store.todaySchedule.week != nil,
                               selectWeek: { route = .weeks },
                               changeWeek: { store.changeWeek(by: $0) },
                               jumpToToday: { store.jumpToToday() })
            HStack(spacing: 4) {
                if let start = store.presentation.days.first?.date,
                   let end = store.presentation.days.last?.date {
                    Text(start, format: .dateTime.month().day())
                    Text("—")
                    Text(end, format: .dateTime.month().day())
                }
                Spacer(minLength: 4)
                Text(store.doc.term).lineLimit(1)
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func schedule(size: CGSize, scrolls: Bool) -> some View {
        ZStack(alignment: .top) {
            if mode == .cards {
                WeekGrid(snapshot: store.presentation, today: store.todaySchedule.date,
                         viewport: size, scrolls: scrolls, transitionNamespace: courseTransitions) { cluster, source in
                    if cluster.isConflict { route = .conflict(cluster, store.week) }
                    else { route = .course(cluster.lessons[0].course, store.week, source) }
                }.transition(.opacity)
            } else {
                if scrolls {
                    ScrollView(.vertical) { weekList }
                        .scrollBounceBehavior(.basedOnSize)
                        .transition(.opacity)
                } else {
                    weekList.transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : InterfaceMotion.content, value: mode)
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
    }

    private var weekList: some View {
        WeekListView(snapshot: store.presentation, today: store.todaySchedule.date, transitionNamespace: courseTransitions) {
            route = .course($0, store.week, $1)
        }
    }
}

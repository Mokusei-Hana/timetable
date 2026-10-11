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

private struct ExpandedCourse {
    let sessionID = UUID()
    let cluster: CourseCluster
    let week: Int
    let sourceID: String
    let fontSize: CGFloat
}

struct ContentView: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("scheduleViewMode") private var mode: ScheduleViewMode = .cards
    @State private var route: SheetRoute?
    @State private var expandedCourse: ExpandedCourse?
    @AccessibilityFocusState private var focusedSourceID: String?
    @Namespace private var courseTransitions

    private var blocksBackground: Bool { expandedCourse != nil }

    var body: some View {
        timetable
        .tint(Design.accent(dark: colorScheme == .dark))
        .accentColor(Design.accent(dark: colorScheme == .dark))
        .respectMotionPreference()
        .onChange(of: store.week) { _, _ in closeCourse(animated: false) }
        .onChange(of: mode) { _, _ in closeCourse(animated: false) }
        .onChange(of: dynamicType) { _, _ in closeCourse(animated: false) }
        .onChange(of: route?.id) { _, id in if id != nil { closeCourse(animated: false) } }
        // 数据替换、编辑或删除时不再使用旧课程或旧位置；不触发课表刷新。
        .onReceive(store.$doc.dropFirst()) { _ in closeCourse(animated: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshToday() }
        }
    }

    private var timetable: some View {
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
            .allowsHitTesting(!blocksBackground)
            .accessibilityHidden(blocksBackground)
            // 源卡片保留在非 Lazy 网格中；展开期间固定滚动位置。
            .scrollDisabled(blocksBackground)
            // 在导航内容层读取锚点，避免跨 NavigationStack 展示边界传递。
            .overlayPreferenceValue(CourseCardAnchors.self) { anchors in
                GeometryReader { geometry in
                    if let selection = expandedCourse {
                        CourseCardExpansion(
                            cluster: selection.cluster, week: selection.week, fontSize: selection.fontSize,
                            sourceFrame: anchors[selection.sourceID].map { geometry[$0] },
                            sourceViewport: anchors[CourseCardAnchors.viewportID].map { geometry[$0] },
                            viewport: geometry.size, safeArea: geometry.safeAreaInsets
                        ) { fallback in
                            // 已移除视图的动画回调不能关闭后来打开的同一门课程。
                            if expandedCourse?.sessionID == selection.sessionID {
                                closeCourse(animated: fallback)
                                if !fallback { focusedSourceID = selection.sourceID }
                            }
                        }
                        .id(selection.sessionID)
                        .transition(.opacity)
                        .zIndex(1)
                    }
                }
                .allowsHitTesting(blocksBackground)
            }
            .animation(reduceMotion ? nil : InterfaceMotion.content, value: store.hasData)
            .background(Design.background)
            .navigationTitle("课程表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { route = .settings } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("数据管理")
                        .disabled(blocksBackground)
                        .accessibilityHidden(blocksBackground)
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
            .timetableAlert(store, enabled: route == nil && !blocksBackground)
        }
    }

    private func openCourse(_ cluster: CourseCluster, sourceID: String, fontSize: CGFloat) {
        guard !blocksBackground, route == nil else { return }
        // Overlay 首帧复制真实源卡片；锚点或测量缺失时也能展示摘要。
        focusedSourceID = nil
        expandedCourse = ExpandedCourse(cluster: cluster, week: store.week, sourceID: sourceID, fontSize: fontSize)
    }

    private func closeCourse(animated: Bool = false) {
        guard blocksBackground else { return }
        focusedSourceID = nil
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.14)) { expandedCourse = nil }
        } else {
            // 源卡片可能已随周次、模式或数据改变而消失，避免匹配到新布局。
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                expandedCourse = nil
            }
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
                         viewport: size, scrolls: scrolls,
                         expandedSourceID: expandedCourse?.sourceID,
                         sourceFocus: $focusedSourceID) { cluster, source, fontSize in
                    guard !blocksBackground, route == nil else { return }
                    if cluster.isConflict { route = .conflict(cluster, store.week) }
                    else { openCourse(cluster, sourceID: source, fontSize: fontSize) }
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

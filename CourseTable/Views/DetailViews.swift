import SwiftUI
import UniformTypeIdentifiers

/// 网格专用的简明摘要；列表与其他入口继续使用完整 CourseDetailView。
struct CompactCourseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .subheadline) private var symbolWidth: CGFloat = 18
    let lesson: LessonPresentation
    let week: Int
    let showDetails: () -> Void
    let close: () -> Void
    let closeFocus: AccessibilityFocusState<Bool>.Binding

    private var ink: Color { Design.ink(lesson.colorIndex, dark: colorScheme == .dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(lesson.course.name)
                    .font(.headline).foregroundStyle(ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                actions.fixedSize()
            }
            ViewThatFits(in: .vertical) {
                information.fixedSize(horizontal: false, vertical: true)
                ScrollView(.vertical) { information }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(16)
        .background {
            // 测量最终选中的布局及标题操作区，避免 ViewThatFits 内部候选视图的测量竞争。
            GeometryReader { geometry in
                Color.clear.preference(key: CourseCardSize.self, value: geometry.size)
            }
        }
        .textSelection(.enabled)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    private var actions: some View {
        HStack(spacing: 0) {
            Button(action: showDetails) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("查看完整课程详情")
            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("关闭课程信息")
            .accessibilityFocused(closeFocus)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ink)
        .buttonStyle(.plain)
        .background(ink.opacity(colorScheme == .dark ? 0.12 : 0.07), in: Capsule(style: .continuous))
    }

    private var information: some View {
        let course = lesson.course
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(TimetableDoc.dayName(course.day)) · \(lesson.sections)")
                .font(.caption.weight(.medium)).foregroundStyle(ink)
            informationRow(course.time, symbol: "clock")
                .monospacedDigit()
            informationRow(course.location.isEmpty ? "地点未提供" : course.location, symbol: "mappin.and.ellipse")
                .lineLimit(dynamicType.isAccessibilitySize ? 4 : 3)
            informationRow(course.teacher.isEmpty ? "教师未提供" : course.teacher, symbol: "person")
                .lineLimit(2)
            informationRow("第 \(week) 周 · \(course.weeksText.isEmpty ? "周次未提供" : course.weeksText)", symbol: "calendar")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func informationRow(_ text: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).frame(width: symbolWidth).foregroundStyle(ink)
                .accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CourseDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: TimetableStore
    let course: Course
    let week: Int

    private var sections: String {
        store.doc.blocks.filter { $0.index >= course.startBlock && $0.index < course.startBlock + course.span }
            .map(\.label).joined(separator: "、")
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("课程", systemImage: "book.closed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Design.ink(course.colorSeed % 8, dark: colorScheme == .dark))
                    Text(course.name).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("第 \(week) 周 · \(TimetableDoc.dayName(course.day))")
                        .font(.subheadline).foregroundStyle(Color.accentColor)
                    if let date = store.doc.date(day: course.day, week: week) {
                        Text(date, format: .dateTime.year().month().day())
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }.listRowBackground(Color.clear)
            Section("上课安排") {
                detail("上课时间", course.time)
                detail("节次", sections)
                detail("上课地点", course.location)
                detail("任课老师", course.teacher)
                detail("上课周次", course.weeksText)
            }
            Section("课程信息") {
                detail("班级", course.className)
                detail("考核方式", course.examType)
                detail("总学时", course.hours.map { "\($0) 学时" } ?? "未提供")
                detail("课程编号", course.courseCode)
                detail("课程 ID", course.id)
            }
        }
        .navigationTitle("课程详情")
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.enabled)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.isEmpty ? "未提供" : value).font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 4)
    }
}

struct TodayAgendaView: View {
    @Namespace private var courseTransitions
    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = TodaySnapshot(schedule: store.todaySchedule, now: context.date)
            List {
                if today.lessons.isEmpty {
                    ContentUnavailableView(today.emptyTitle, systemImage: "sun.max",
                                           description: Text("你可以返回课表查看其他日期。"))
                }
                ForEach(today.lessons) { course in
                    NavigationLink {
                        CourseDetailView(course: course, week: today.week ?? 1)
                            .courseZoomDestination(course.id, in: courseTransitions)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(course.time).monospacedDigit()
                                if course.minuteRange?.contains(today.minute) == true {
                                    Text("进行中").foregroundStyle(Color.accentColor)
                                } else if (course.minuteRange?.upperBound ?? 0) <= today.minute {
                                    Text("已结束").foregroundStyle(.secondary)
                                }
                            }.font(.caption.weight(.medium))
                            Text(course.name).font(.headline)
                            Text(course.shortLocation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .courseZoomSource(course.id, in: courseTransitions)
                    }
                }
            }
            .onChange(of: context.date) { _, date in store.refreshToday(date) }
        }
        .navigationTitle("今日安排")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WeekPickerView: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(1...store.totalWeeks, id: \.self) { week in
                    Button {
                        store.selectWeek(week)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text("第 \(week) 周").font(.headline)
                                if store.week == week { Image(systemName: "checkmark.circle.fill") }
                            }
                            if let date = store.doc.monday(ofWeek: week) {
                                Text(date, format: .dateTime.month().day()).font(.caption)
                            }
                            Text(store.doc.week(containing: Date()) == week ? "本周" : " ")
                                .font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .foregroundStyle(store.week == week ? Color.accentColor : Color.primary)
                        .background(store.week == week ? Color.accentColor.opacity(0.12) : Design.surface,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(CoursePressStyle())
                    .accessibilityAddTraits(store.week == week ? .isSelected : [])
                    .accessibilityLabel("第 \(week) 周\(store.week == week ? "，已选中" : "")")
                }
            }.padding(Design.inset)
        }
        .background(Design.background)
        .navigationTitle("选择周次")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: TimetableStore
    @State private var importing = false
    @State private var successfulOperations = 0

    var body: some View {
        Form {
            Section {
                Label("只属于你的课表", systemImage: "iphone")
                    .font(.headline).padding(.vertical, 8)
                Text("无需登录，课程保存在这台 iPhone 上。App 不会主动联网，也不会上传课表。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if store.isBusy { ProgressView("正在处理课表…") }
            Section("当前数据") {
                LabeledContent("来源", value: store.sourceName)
                if store.hasData {
                    LabeledContent("学期", value: store.doc.term)
                    LabeledContent("学期开始", value: store.doc.termStartDate)
                    LabeledContent("总周数", value: "\(store.totalWeeks) 周")
                    LabeledContent("课程安排", value: "\(store.doc.courses.count) 条")
                    LabeledContent("导出日期", value: store.doc.exportedAt)
                }
            }
            Section {
                ControlGlassGroup(spacing: 12) {
                    VStack(spacing: 12) {
                        Button { importing = true } label: {
                            Label("导入课表文件", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .adaptiveActionStyle(prominent: true)
                        .disabled(store.isBusy)
                        Button {
                            Task {
                                guard !store.isBusy else { return }
                                await store.resetToBundled()
                                if store.hasData && !store.isImported { successfulOperations += 1 }
                            }
                        } label: {
                            Label("恢复自带课表", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .adaptiveActionStyle()
                        .disabled(store.isBusy || (!store.isImported && store.hasData))
                    }
                }
                .buttonBorderShape(.capsule)
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            } header: {
                Text("更新课表")
            } footer: {
                Text("支持 JSON 和 DAT，最大 10 MB。导入成功后替换当前课表；恢复自带课表会移除 App 保存的导入副本，不会删除你原来的文件。")
            }
        }
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { result in
            switch result {
            case .success(let url):
                Task {
                    if await store.importFile(at: url) { successfulOperations += 1 }
                }
            case .failure(let error):
                if let cocoa = error as? CocoaError, cocoa.code == .userCancelled { return }
                store.message = "无法打开文件：\(error.localizedDescription)"
            }
        }
        .sensoryFeedback(.success, trigger: successfulOperations)
        .respectMotionPreference()
        .timetableAlert(store)
    }
}

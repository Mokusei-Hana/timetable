import SwiftUI
import UniformTypeIdentifiers

struct CourseDetailView: View {
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
    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = TodaySnapshot(doc: store.doc, now: context.date)
            List {
                if today.lessons.isEmpty {
                    ContentUnavailableView(today.emptyTitle, systemImage: "sun.max",
                                           description: Text("你可以返回课表查看其他日期。"))
                }
                ForEach(today.lessons) { course in
                    NavigationLink {
                        CourseDetailView(course: course, week: today.week ?? 1)
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
                        }.padding(.vertical, 8)
                    }
                }
            }
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
                    .buttonStyle(.plain)
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

    var body: some View {
        Form {
            Section {
                Label("只属于你的课表", systemImage: "iphone")
                    .font(.headline).padding(.vertical, 8)
                Text("无需登录，课程保存在这台 iPhone 上。App 不会主动联网，也不会上传课表。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
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
                Button { importing = true } label: {
                    Label("导入课表文件", systemImage: "square.and.arrow.down")
                }
                Button { store.resetToBundled() } label: {
                    Label("恢复自带课表", systemImage: "arrow.counterclockwise")
                }.disabled(!store.isImported && store.hasData)
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
            case .success(let url): store.importFile(at: url)
            case .failure(let error):
                if let cocoa = error as? CocoaError, cocoa.code == .userCancelled { return }
                store.message = "无法打开文件：\(error.localizedDescription)"
            }
        }
        .timetableAlert(store)
    }
}

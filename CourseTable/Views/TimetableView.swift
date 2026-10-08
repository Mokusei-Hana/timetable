import SwiftUI
import UniformTypeIdentifiers

struct TimetableView: View {
    @EnvironmentObject private var store: TimetableStore

    /// 显示五天还是七天（关掉 App 再打开也记得）
    @AppStorage("dayCount") private var dayCount: Int = 5

    @State private var showWeekPicker = false
    @State private var showImporter = false
    @State private var selectedCourse: Course?

    /// 左边那列节次标签的宽度
    private let labelWidth: CGFloat = 44
    /// 一个大节有多高
    private let rowHeight: CGFloat = 86
    /// 大节之间留的空隙
    private let rowGap: CGFloat = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekBar
                if store.doc.blocks.isEmpty {
                    emptyState
                } else {
                    headerRow
                    grid
                }
                footerBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(store.doc.term)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $selectedCourse) { course in
                CourseDetailView(course: course, blocks: store.doc.blocks)
            }
            .sheet(isPresented: $showWeekPicker) {
                WeekPickerView(week: $store.week, totalWeeks: store.totalWeeks)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    store.importFile(at: url)
                case .failure(let error):
                    store.message = "选择文件失败：\(error.localizedDescription)"
                }
            }
            .alert("提示", isPresented: messageBinding) {
                Button("知道了") { store.message = nil }
            } message: {
                Text(store.message ?? "")
            }
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )
    }

    // MARK: - 顶上那一条：翻周

    private var weekBar: some View {
        HStack(spacing: 10) {
            Button {
                store.changeWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            .disabled(store.week <= 1)

            Button {
                showWeekPicker = true
            } label: {
                VStack(spacing: 1) {
                    Text("第\(store.week)周").font(.headline)
                    Text(store.weekRangeText).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(minWidth: 116)
            }

            Button {
                store.changeWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .disabled(store.week >= store.totalWeeks)

            Spacer(minLength: 0)

            if !store.isShowingToday {
                Button("回到本周") { store.jumpToToday() }
                    .font(.footnote)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 星期表头

    private var headerRow: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: labelWidth, height: 1)

            ForEach(store.visibleDays(dayCount: dayCount), id: \.self) { day in
                VStack(spacing: 1) {
                    Text(store.weekdayName(day)).font(.caption).fontWeight(.medium)
                    Text(store.dayNumberText(day)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(store.isToday(day) ? Color.accentColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 课表主体

    private var grid: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 4) {
                blockLabels

                ForEach(store.visibleDays(dayCount: dayCount), id: \.self) { day in
                    dayColumn(day)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    /// 最左边一列：节次标签
    private var blockLabels: some View {
        VStack(spacing: rowGap) {
            ForEach(store.doc.blocks) { block in
                VStack(spacing: 0) {
                    Text(block.shortLabel).font(.system(size: 10))
                    Text(block.sections).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .frame(width: labelWidth, height: rowHeight)
            }
        }
    }

    /// 一天一列。底色是空格子，课块浮在上面按「离顶上多远」摆位置。
    private func dayColumn(_ day: Int) -> some View {
        let courses = store.doc.lessons(day: day, week: store.week)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: rowGap) {
                ForEach(store.doc.blocks) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(store.isToday(day)
                              ? Color.accentColor.opacity(0.07)
                              : Color(.secondarySystemBackground))
                        .frame(height: rowHeight)
                }
            }

            ForEach(courses) { course in
                CourseBlockView(course: course)
                    .frame(height: blockHeight(span: course.span))
                    .offset(y: blockOffset(startBlock: course.startBlock))
                    .onTapGesture { selectedCourse = course }
            }
        }
    }

    private func blockHeight(span: Int) -> CGFloat {
        let blocks = CGFloat(max(1, span))
        return rowHeight * blocks + rowGap * (blocks - 1)
    }

    private func blockOffset(startBlock: Int) -> CGFloat {
        CGFloat(max(0, startBlock)) * (rowHeight + rowGap)
    }

    // MARK: - 底部：五天/七天 + 数据来源

    private var footerBar: some View {
        HStack(spacing: 10) {
            Picker("显示天数", selection: $dayCount) {
                Text("五天").tag(5)
                Text("七天").tag(7)
            }
            .pickerStyle(.segmented)
            .frame(width: 128)

            if dayCount == 5 && store.doc.hasWeekendCourse(week: store.week) {
                Button {
                    dayCount = 7
                } label: {
                    Label("周末有课", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                }
            }

            Spacer(minLength: 0)

            Text(store.sourceName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 没数据时

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("还没读到课表数据").font(.headline)
            Text("可以从右上角菜单里导入一份课表文件")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("导入课表文件") { showImporter = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 右上角菜单

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showImporter = true
                } label: {
                    Label("导入课表文件", systemImage: "square.and.arrow.down")
                }

                Button {
                    store.resetToBundled()
                } label: {
                    Label("用回自带的数据", systemImage: "arrow.clockwise")
                }

                if let exportedAt = store.doc.exportedAt {
                    Text("数据日期：\(exportedAt)")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

#Preview {
    TimetableView()
        .environmentObject(TimetableStore())
}

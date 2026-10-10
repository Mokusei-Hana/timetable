import SwiftUI

/// 时钟只使这个小视图更新，周网格不依赖分钟变化。
struct TodaySummaryView: View {
    let schedule: TodaySchedule
    let transitionNamespace: Namespace.ID
    let openCourse: (Course, Int, String) -> Void
    let openAgenda: () -> Void
    let tick: (Date) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("todaySummaryExpanded") private var expanded = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = TodaySnapshot(schedule: schedule, now: context.date)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Button(action: openAgenda) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("今天").fontWeight(.semibold)
                                Text(context.date, format: .dateTime.month().day().weekday(.abbreviated))
                            }
                            if let week = schedule.week {
                                Text("第 \(week) 周 · \(schedule.lessons.count) 节课 · 查看安排")
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())
                            }
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }.buttonStyle(CoursePressStyle())
                    Button {
                        withAnimation(reduceMotion ? nil : InterfaceMotion.expansion) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).frame(width: 44, height: 44)
                            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    }
                    .buttonStyle(CoursePressStyle())
                    .sensoryFeedback(.selection, trigger: expanded)
                    .accessibilityValue(expanded ? "已展开" : "已收起")
                    .accessibilityLabel(expanded ? "收起今日信息" : "展开今日信息")
                }
                if let course = state.focus, let week = state.week {
                    let source = "today-\(week)-\(course.id)"
                    Button { openCourse(course, week, source) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(state.status) · \(course.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary).lineLimit(expanded ? nil : 1)
                                .contentTransition(.opacity)
                            Text("\(course.time) · \(course.shortLocation)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(expanded ? nil : 1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CoursePressStyle())
                    .courseZoomSource(source, in: transitionNamespace)
                    .animation(reduceMotion ? nil : InterfaceMotion.content, value: state.status + course.id)
                } else {
                    Text(state.emptyTitle).font(.subheadline.weight(.medium)).padding(.bottom, 4)
                    if expanded {
                        Text(state.week == nil ? "仍可浏览整个学期的课程安排。" : "留些时间给自己。")
                            .font(.caption).foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Design.surface, in: RoundedRectangle(cornerRadius: 12))
            .respectMotionPreference()
            .onChange(of: context.date) { _, date in tick(date) }
        }
    }
}

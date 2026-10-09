import SwiftUI

struct WeekGrid: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 144
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 132
    @ScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var railWidth: CGFloat = 48
    let showWeekend: Bool
    let select: (Course) -> Void
    private let gap = Design.gap
    private var gridHeight: CGFloat { rowHeight * 6 + gap * 5 }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: gap) {
                Text("节次").font(.caption).foregroundStyle(.secondary)
                    .frame(height: headerHeight)
                ForEach(store.doc.blocks) { block in
                    VStack(spacing: 4) {
                        Text(String(format: "%02d", block.index * 2 + 1)).font(.subheadline.weight(.semibold))
                        Text(String(format: "%02d", block.index * 2 + 2)).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: rowHeight, alignment: .top)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(block.label)
                }
            }
            .frame(width: railWidth)
            .padding(.leading, 8)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(1..<(showWeekend ? 8 : 6), id: \.self) { day in
                        dayColumn(day)
                    }
                }.padding(.trailing, Design.inset)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func dayColumn(_ day: Int) -> some View {
        let layout = DayLayout(courses: store.doc.lessons(day: day, week: store.week))
        let width = columnWidth * CGFloat(layout.lanes.count) + gap * CGFloat(layout.lanes.count - 1)
        let date = store.doc.date(day: day, week: store.week)
        let isToday = date.map { TimetableDoc.calendar.isDateInToday($0) } ?? false
        return VStack(spacing: gap) {
            VStack(spacing: 4) {
                Text(isToday ? "今天 · \(TimetableDoc.dayName(day))" : TimetableDoc.dayName(day))
                    .font(.caption.weight(.semibold))
                if let date { Text(date, format: .dateTime.day()).font(.title3.weight(.semibold)) }
            }
            .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            .frame(width: width, height: headerHeight)
            .background(isToday ? Color.accentColor.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .top, spacing: gap) {
                ForEach(layout.lanes.indices, id: \.self) { lane in
                    ZStack(alignment: .topLeading) {
                        ForEach(layout.lanes[lane]) { course in
                            courseCard(course)
                                .frame(width: columnWidth, height: rowHeight * CGFloat(course.span) + gap * CGFloat(course.span - 1))
                                .offset(y: CGFloat(course.startBlock) * (rowHeight + gap))
                        }
                    }
                    .frame(width: columnWidth, height: gridHeight, alignment: .topLeading)
                }
            }
        }
        .frame(width: width)
    }

    private func courseCard(_ course: Course) -> some View {
        let dark = colorScheme == .dark
        return Button { select(course) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(course.name).font(.subheadline.weight(.semibold)).lineLimit(4)
                Spacer(minLength: 0)
                Text(course.shortLocation.isEmpty ? "地点未提供" : course.shortLocation)
                    .font(.caption).lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Design.ink(course, dark: dark))
            .background(Design.fill(course, dark: dark), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(course.name)，\(TimetableDoc.dayName(course.day))，\(course.time)，\(course.location)")
        .accessibilityHint("查看完整课程信息")
    }
}

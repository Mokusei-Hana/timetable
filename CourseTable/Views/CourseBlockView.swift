import SwiftUI

/// 课表里的一格课。
struct CourseBlockView: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(course.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(course.shortLocation)
                .font(.system(size: 9))
                .lineLimit(2)
                .opacity(0.75)
        }
        .foregroundStyle(Palette.blockText)
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.fill(for: course))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    CourseBlockView(course: Course(
        id: "demo",
        name: "高等数学",
        teacher: "张老师",
        location: "教学楼101(示例教室)",
        day: 1,
        startBlock: 0,
        span: 1,
        weeks: [3, 5, 7],
        weeksText: "3,5,7",
        time: "08:20-10:00",
        className: "示例班级",
        examType: "考查",
        hours: 16,
        courseCode: "0000000"
    ))
    .frame(width: 62, height: 86)
    .padding()
}

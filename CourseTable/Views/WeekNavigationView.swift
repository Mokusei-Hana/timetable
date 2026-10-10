import SwiftUI

/// 周次控件独立动画，翻周不会给整张课程网格添加隐式弹簧。
struct WeekNavigationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @State private var feedback = 0
    let week: Int
    let totalWeeks: Int
    let currentWeek: Int
    let inTerm: Bool
    let selectWeek: () -> Void
    let changeWeek: (Int) -> Void
    let jumpToToday: () -> Void

    private var showsReturn: Bool { week != currentWeek }

    var body: some View {
        ControlGlassGroup(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { title; Spacer(minLength: 0); actions }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    HStack { Spacer(); actions }
                }
            }
        }
        .animation(reduceMotion ? nil : InterfaceMotion.control, value: showsReturn)
        .sensoryFeedback(.selection, trigger: feedback)
        .respectMotionPreference()
    }

    private var title: some View {
        Button(action: selectWeek) {
            HStack(spacing: 6) {
                Text("第 \(week) 周")
                    .font(.title3.bold()).monospacedDigit()
                    .contentTransition(.numericText(value: Double(week)))
                    .animation(reduceMotion ? nil : InterfaceMotion.content, value: week)
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44).fixedSize(horizontal: true, vertical: false)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .controlGlass(id: "week-picker", in: glassNamespace)
        .accessibilityLabel("第 \(week) 周，选择周次")
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                jumpToToday()
                feedback += 1
            } label: {
                Group {
                    if showsReturn {
                        Text(inTerm ? "本周" : "当前")
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 12)
                    } else {
                        Image(systemName: "calendar")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .controlGlass(id: "return-to-today", in: glassNamespace)
            .accessibilityLabel(inTerm ? "回到本周并跟随今天" : "回到当前学期位置")
            HStack(spacing: 0) {
                Button { changeWeek(-1); feedback += 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.disabled(week == 1).accessibilityLabel("上一周")
                Button { changeWeek(1); feedback += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.disabled(week == totalWeeks).accessibilityLabel("下一周")
            }
            .buttonStyle(CoursePressStyle())
            .controlGlass(id: "week-arrows", in: glassNamespace, interactive: false)
        }
    }
}

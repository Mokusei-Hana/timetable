import SwiftUI

enum ScheduleViewMode: String, CaseIterable, Identifiable {
    case cards, list
    var id: String { rawValue }
    var title: String { self == .cards ? "卡片" : "列表" }
    var symbol: String { self == .cards ? "rectangle.grid.3x2" : "list.bullet" }
}

/// 参考 smooth-option-switcher 的等宽轨道与常驻指示器；仅使用 SwiftUI。
struct ViewModeSwitcher: View {
    @Binding var selection: ScheduleViewMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleViewMode.allCases) { mode in
                Button { selection = mode } label: {
                    Label(mode.title, systemImage: mode.symbol)
                        .font(.subheadline.weight(selection == mode ? .semibold : .regular))
                        .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: max(44, height))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .background {
            GeometryReader { geometry in
                // 指示器始终为同一个 View，快速反向点击从当前动画位置继续。
                RoundedRectangle(cornerRadius: 8)
                    .fill(Design.surface)
                    .frame(width: geometry.size.width / 2, height: geometry.size.height)
                    .offset(x: selection == .cards ? 0 : geometry.size.width / 2)
                    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.94), value: selection)
                    .accessibilityHidden(true)
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("课表显示方式")
    }
}

import SwiftUI

/// 动效只用于用户操作；时钟、文件解析和课程索引不参与动画状态。
enum InterfaceMotion {
    static let control = Animation.spring(response: 0.30, dampingFraction: 0.92)
    static let expansion = Animation.spring(response: 0.34, dampingFraction: 0.94)
    static let content = Animation.easeInOut(duration: 0.18)
    static let press = Animation.easeOut(duration: 0.12)
    static let courseOpen = Animation.spring(response: 0.40, dampingFraction: 0.90)
    static let courseClose = Animation.spring(response: 0.34, dampingFraction: 0.92)
}

/// 内容卡片保持不透明，按压只改变显示变换，不重新测量布局。
struct CoursePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.82 : 1))
            .animation(reduceMotion ? nil : InterfaceMotion.press, value: configuration.isPressed)
    }
}

/// 同一操作区共享玻璃渲染；旧 SDK 完全不引用新符号。
struct ControlGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct ControlGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let id: String
    let namespace: Namespace.ID
    let interactive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.interactive(interactive && !reduceMotion), in: Capsule())
                .glassEffectID(id, in: namespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            content.background(Design.surface, in: Capsule())
        }
        #else
        content.background(Design.surface, in: Capsule())
        #endif
    }
}

private struct AdaptiveActionStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency, !reduceMotion {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent) }
        else { content.buttonStyle(.bordered) }
    }
}

private struct CourseZoomSource: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else { content }
        #else
        content
        #endif
    }
}

private struct CourseZoomDestination: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String?
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *), !reduceMotion, let id {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else { content }
        #else
        content
        #endif
    }
}

private struct MotionAccessibility: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

extension View {
    func controlGlass(id: String, in namespace: Namespace.ID, interactive: Bool = true) -> some View {
        modifier(ControlGlassSurface(id: id, namespace: namespace, interactive: interactive))
    }

    func adaptiveActionStyle(prominent: Bool = false) -> some View {
        modifier(AdaptiveActionStyle(prominent: prominent))
    }

    func courseZoomSource(_ id: String, in namespace: Namespace.ID) -> some View {
        modifier(CourseZoomSource(id: id, namespace: namespace))
    }

    func courseZoomDestination(_ id: String?, in namespace: Namespace.ID) -> some View {
        modifier(CourseZoomDestination(id: id, namespace: namespace))
    }

    func respectMotionPreference() -> some View { modifier(MotionAccessibility()) }
}

/// 锚点随 ScrollView 正确转换坐标，不把每次滚动的几何值写回课表状态。
struct CourseCardAnchors: PreferenceKey {
    static let viewportID = "course-grid-viewport"
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct CourseCardSize: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// 用容器的同一弹簧进度协调文字：原内容先淡出，正文在空间足够后才显现。
private struct CourseContentVisibility: AnimatableModifier {
    var progress: Double
    let source: Bool
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let opacity = source ? 1 - min(1, max(0, progress / 0.28)) : min(1, max(0, (progress - 0.80) / 0.20))
        return content.opacity(opacity)
    }
}

/// 一个持续存在的容器直接插值 frame / position / 圆角；文字不参与几何缩放。
struct CourseCardExpansion: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cluster: CourseCluster
    let week: Int
    let fontSize: CGFloat
    let sourceFrame: CGRect?
    let sourceViewport: CGRect?
    let viewport: CGSize
    let safeArea: EdgeInsets
    let showDetails: () -> Void
    let dismiss: (Bool) -> Void
    @State private var collapsedFrame: CGRect
    @State private var collapsedViewport: CGRect
    @State private var detailFrame: CGRect?
    @State private var expanded = false
    @State private var closing = false
    @State private var transitionID = UUID()
    @AccessibilityFocusState private var closeFocused: Bool

    init(cluster: CourseCluster, week: Int, fontSize: CGFloat, sourceFrame: CGRect?,
         sourceViewport: CGRect?, viewport: CGSize, safeArea: EdgeInsets,
         showDetails: @escaping () -> Void, dismiss: @escaping (Bool) -> Void) {
        self.cluster = cluster
        self.week = week
        self.fontSize = fontSize
        self.sourceFrame = sourceFrame
        self.sourceViewport = sourceViewport
        self.viewport = viewport
        self.safeArea = safeArea
        self.showDetails = showDetails
        self.dismiss = dismiss
        let bounds = Self.safeBounds(viewport, insets: safeArea)
        let visible = (sourceViewport ?? bounds).intersection(bounds)
        if let sourceFrame, Self.isValidFrame(sourceFrame), sourceFrame.intersects(visible) {
            _collapsedFrame = State(initialValue: sourceFrame)
            _collapsedViewport = State(initialValue: visible)
        } else {
            // 缺少或无效的锚点只能影响形变，不能阻断课程信息展示。
            let width = max(1, min(bounds.width * 0.88, bounds.width - 24))
            let height = max(1, min(260, bounds.height - 24))
            _collapsedFrame = State(initialValue: CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                                                        width: width, height: height))
            _collapsedViewport = State(initialValue: bounds)
        }
    }

    private static func safeBounds(_ size: CGSize, insets: EdgeInsets) -> CGRect {
        CGRect(x: insets.leading, y: insets.top,
               width: max(0, size.width - insets.leading - insets.trailing),
               height: max(0, size.height - insets.top - insets.bottom))
    }

    private static func isValidFrame(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }

    private var availableBounds: CGRect { Self.safeBounds(viewport, insets: safeArea) }
    private var cardWidth: CGFloat { max(1, min(availableBounds.width * 0.88, availableBounds.width - 24)) }
    private var heightLimit: CGFloat { max(1, min(dynamicType.isAccessibilitySize ? 360 : 300, availableBounds.height - 24)) }

    private var targetFrame: CGRect {
        detailFrame ?? fittedFrame(height: 260)
    }

    private func fittedFrame(height: CGFloat) -> CGRect {
        let height = min(height, heightLimit)
        let bounds = availableBounds
        return CGRect(x: bounds.midX - cardWidth / 2, y: bounds.midY - height / 2,
                      width: cardWidth, height: height)
    }

    private var currentFrame: CGRect { expanded ? targetFrame : collapsedFrame }
    private var radius: CGFloat { expanded ? 24 : 8 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(expanded ? 0.14 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .accessibilityHidden(true)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: expanded)
            ZStack(alignment: .topLeading) {
                surface(Design.fill(cluster.lessons[0].colorIndex, dark: colorScheme == .dark))
                    .shadow(color: .black.opacity(expanded ? (colorScheme == .dark ? 0.22 : 0.12) : 0),
                            radius: expanded ? 12 : 0, x: 0, y: expanded ? 4 : 0)
                    .allowsHitTesting(false)
                GridCourseCardContent(cluster: cluster, width: collapsedFrame.width,
                                      height: collapsedFrame.height, fontSize: fontSize)
                    .frame(width: collapsedFrame.width, height: collapsedFrame.height)
                    .position(x: currentFrame.minX + collapsedFrame.width / 2,
                              y: currentFrame.minY + collapsedFrame.height / 2)
                    .modifier(CourseContentVisibility(progress: expanded ? 1 : 0, source: true))
                    .mask { surface(.white) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                CompactCourseCard(lesson: cluster.lessons[0], week: week, showDetails: openDetails,
                                  close: close, closeFocus: $closeFocused)
                    .frame(width: cardWidth)
                    .frame(maxHeight: heightLimit)
                    .frame(height: detailFrame?.height)
                    .contentShape(Rectangle())
                    // 内容始终按最终宽度排版；即使容器还在收缩也不压缩字形。
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }
                    .modifier(CourseContentVisibility(progress: expanded ? 1 : 0, source: false))
                    .mask { surface(.white) }
                    .allowsHitTesting(expanded && !closing)
                    .accessibilityHidden(!expanded || closing)
            }
            .mask {
                // 屏幕边缘的部分卡片首尾沿用 ScrollView 的裁切范围。
                let bounds = expanded ? availableBounds : collapsedViewport
                Rectangle().frame(width: bounds.width, height: bounds.height)
                    .position(x: bounds.midX, y: bounds.midY)
            }
        }
        // 普通关闭会令 expanded 变为 false；进入完整详情则原地淡出，不先缩回网格。
        .opacity(closing && expanded ? 0 : 1)
        .onPreferenceChange(CourseCardSize.self) { size in
            guard detailFrame == nil, !expanded, !closing,
                  size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            // 首帧测量仅优化高度；未返回或无效时使用紧凑的默认高度，展开后不再跳动。
            withTransaction(transaction) { detailFrame = fittedFrame(height: size.height) }
            open()
        }
        .task {
            // 先让首轮布局提交测量；不依赖回调成功，也不使用定时延迟。
            await Task.yield()
            guard !Task.isCancelled else { return }
            open()
        }
        .onChange(of: viewport) { old, _ in
            // 初次布局从零尺寸变为有效尺寸时仍应正常显示。
            if old.width > 0 && old.height > 0 { dismiss(true) }
        }
        .onChange(of: safeArea) { _, _ in dismiss(true) }
        .onDisappear { transitionID = UUID() }
    }

    private func surface(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(color)
            .frame(width: currentFrame.width, height: currentFrame.height)
            .position(x: currentFrame.midX, y: currentFrame.midY)
    }

    private func open() {
        guard !expanded, !closing else { return }
        if detailFrame == nil {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { detailFrame = fittedFrame(height: 260) }
        }
        let token = transitionID
        withAnimation(reduceMotion ? nil : InterfaceMotion.courseOpen, completionCriteria: .removed) {
            expanded = true
        } completion: {
            if transitionID == token && !closing { closeFocused = true }
        }
    }

    private func close() {
        guard !closing else { return }
        closeFocused = false
        let token = UUID()
        transitionID = token
        let bounds = availableBounds
        let visible = (sourceViewport ?? bounds).intersection(bounds)
        guard let sourceFrame, Self.isValidFrame(sourceFrame), sourceFrame.intersects(visible) else {
            // 源卡片不可见时只淡出，不将容器瞬移到旧坐标。
            dismiss(true)
            return
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            collapsedFrame = sourceFrame
            collapsedViewport = visible
        }
        // 可在展开中直接反向；同一个容器从当前呈现位置重新定向。
        withAnimation(reduceMotion ? nil : InterfaceMotion.courseClose, completionCriteria: .removed) {
            closing = true
            expanded = false
        } completion: {
            if transitionID == token { dismiss(false) }
        }
    }

    private func openDetails() {
        guard !closing else { return }
        closeFocused = false
        let token = UUID()
        transitionID = token
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14), completionCriteria: .removed) {
            closing = true
        } completion: {
            if transitionID == token { showDetails() }
        }
    }
}

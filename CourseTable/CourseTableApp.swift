import SwiftUI

@main
struct CourseTableApp: App {
    @StateObject private var store = TimetableStore()

    var body: some Scene {
        WindowGroup {
            TimetableView()
                .environmentObject(store)
        }
    }
}

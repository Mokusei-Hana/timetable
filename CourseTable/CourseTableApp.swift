import SwiftUI

@main
@MainActor
struct CourseTableApp: App {
    @StateObject private var store = TimetableStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

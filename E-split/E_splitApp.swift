import SwiftData
import SwiftUI

@main
struct E_splitApp: App {
    private let container: ModelContainer
    private let dependencies: AppDependencies

    init() {
        let modelContainer: ModelContainer
        do {
            modelContainer = try SplitExpenseSchema.makeContainer()
        } catch {
            fatalError("Unable to create the local data store.")
        }
        container = modelContainer
        dependencies = .live(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencies, dependencies)
                .appTinted()
        }
    }
}

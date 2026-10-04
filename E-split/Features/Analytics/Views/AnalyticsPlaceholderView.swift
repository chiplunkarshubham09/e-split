import SwiftUI

struct AnalyticsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Analytics coming next",
            systemImage: "chart.bar",
            description: Text("Spending charts will appear here after the core split flow is stable.")
        )
        .navigationTitle("Analytics")
    }
}

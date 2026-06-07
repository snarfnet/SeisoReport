import SwiftUI

@main
struct SeisoReportApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if !store.roleSelected {
                    RoleSelectView()
                } else if store.isAdmin {
                    AdminView()
                } else {
                    WorkerTabView()
                }
            }
            .environment(store)
        }
    }
}

struct WorkerTabView: View {
    var body: some View {
        TabView {
            WorkerReportView()
                .tabItem {
                    Label("報告書", systemImage: "doc.text.fill")
                }

            ReportHistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

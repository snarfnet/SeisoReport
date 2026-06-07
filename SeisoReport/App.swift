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
    @Environment(DataStore.self) private var store
    @State private var showScanner = false
    @State private var scanResult: String?

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScanSheet(store: store, onDismiss: { showScanner = false })
        }
    }
}

private struct QRScanSheet: View {
    let store: DataStore
    let onDismiss: () -> Void
    @State private var message: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerView { code in
                    if store.importFromQR(code) {
                        message = "設定を読み込みました\n作業員: \(store.workerName)\n物件数: \(store.properties.count)"
                        success = true
                    } else {
                        message = "QRコードを読み取れませんでした"
                        success = false
                    }
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Text("管理者のQRコードをスキャンしてください")
                        .font(.subheadline.bold())
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 60)
                }
            }
            .navigationTitle("QRスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { onDismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert(success ? "読み込み完了" : "エラー", isPresented: .init(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK") {
                    message = nil
                    if success { onDismiss() }
                }
            } message: {
                if let message { Text(message) }
            }
        }
    }
}

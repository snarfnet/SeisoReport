import SwiftUI

struct ReportHistoryView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedPDF: URL?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            Group {
                if store.reportHistory.isEmpty {
                    ContentUnavailableView(
                        "報告書はまだありません",
                        systemImage: "doc.text",
                        description: Text("報告書を送信すると、ここに履歴が表示されます。")
                    )
                } else {
                    List {
                        ForEach(store.reportHistory) { report in
                            Button {
                                selectedPDF = store.pdfURL(for: report)
                                showShare = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(report.propertyName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 12) {
                                        Label(formatDate(report.workDate), systemImage: "calendar")
                                        Label(report.workerName, systemImage: "person")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    Text("作成: \(formatDateTime(report.createdAt))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                store.deleteReport(store.reportHistory[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("送信履歴")
            .sheet(isPresented: $showShare) {
                if let url = selectedPDF {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
}

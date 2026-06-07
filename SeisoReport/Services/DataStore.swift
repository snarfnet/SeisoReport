import Foundation
import UIKit

@Observable
final class DataStore {
    var template: ReportTemplate
    var properties: [Property]
    var workerName: String
    var isAdmin: Bool
    var roleSelected: Bool
    var workers: [Worker]
    var reportHistory: [ReportSummary]

    init() {
        roleSelected = UserDefaults.standard.bool(forKey: "roleSelected")
        isAdmin = UserDefaults.standard.bool(forKey: "isAdmin")
        workerName = UserDefaults.standard.string(forKey: "workerName") ?? ""

        if let data = UserDefaults.standard.data(forKey: "template"),
           let t = try? JSONDecoder().decode(ReportTemplate.self, from: data) {
            template = t
        } else {
            template = ReportTemplate()
        }

        if let data = UserDefaults.standard.data(forKey: "properties"),
           let p = try? JSONDecoder().decode([Property].self, from: data) {
            properties = p
        } else {
            properties = []
        }

        if let data = UserDefaults.standard.data(forKey: "workers"),
           let w = try? JSONDecoder().decode([Worker].self, from: data) {
            workers = w
        } else {
            workers = []
        }

        if let data = UserDefaults.standard.data(forKey: "reportHistory"),
           let h = try? JSONDecoder().decode([ReportSummary].self, from: data) {
            reportHistory = h
        } else {
            reportHistory = []
        }
    }

    func save() {
        UserDefaults.standard.set(isAdmin, forKey: "isAdmin")
        UserDefaults.standard.set(workerName, forKey: "workerName")
        if let data = try? JSONEncoder().encode(template) {
            UserDefaults.standard.set(data, forKey: "template")
        }
        if let data = try? JSONEncoder().encode(properties) {
            UserDefaults.standard.set(data, forKey: "properties")
        }
        if let data = try? JSONEncoder().encode(workers) {
            UserDefaults.standard.set(data, forKey: "workers")
        }
        if let data = try? JSONEncoder().encode(reportHistory) {
            UserDefaults.standard.set(data, forKey: "reportHistory")
        }
    }

    // MARK: - Report History

    private static var reportsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveReport(pdfData: Data, draft: ReportDraft, sectionCount: Int) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "report_\(dateFormatter.string(from: Date())).pdf"
        let fileURL = Self.reportsDirectory.appendingPathComponent(fileName)
        try? pdfData.write(to: fileURL)

        let summary = ReportSummary(
            propertyName: draft.propertyName,
            workerName: draft.workerName,
            workDate: draft.workDate,
            createdAt: Date(),
            pdfFileName: fileName,
            sectionCount: sectionCount
        )
        reportHistory.insert(summary, at: 0)
        save()
        return fileURL
    }

    func pdfURL(for summary: ReportSummary) -> URL {
        Self.reportsDirectory.appendingPathComponent(summary.pdfFileName)
    }

    func deleteReport(_ summary: ReportSummary) {
        let url = pdfURL(for: summary)
        try? FileManager.default.removeItem(at: url)
        reportHistory.removeAll { $0.id == summary.id }
        save()
    }

    func setRole(_ admin: Bool) {
        isAdmin = admin
        roleSelected = true
        UserDefaults.standard.set(true, forKey: "roleSelected")
        save()
    }

    func clearRole() {
        roleSelected = false
        UserDefaults.standard.removeObject(forKey: "roleSelected")
    }

    // Export template as JSON string for QR code
    func exportTemplateJSON() -> String? {
        guard let data = try? JSONEncoder().encode(template) else { return nil }
        return data.base64EncodedString()
    }

    // Import from QR code base64 string (worker name + template + assigned properties)
    func importFromQR(_ base64: String) -> Bool {
        guard let data = Data(base64Encoded: base64) else { return false }

        struct SyncData: Codable {
            let workerName: String?
            let template: ReportTemplate
            let properties: [Property]
        }

        guard let sync = try? JSONDecoder().decode(SyncData.self, from: data) else { return false }
        template = sync.template
        properties = sync.properties
        if let name = sync.workerName, !name.isEmpty {
            workerName = name
        }
        save()
        return true
    }
}

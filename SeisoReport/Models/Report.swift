import Foundation
import SwiftUI

// A completed report entry for one section
struct SectionEntry: Identifiable, Codable {
    var id = UUID()
    var sectionId: UUID
    var floor: Int? // nil if not per-floor
    var photoFileNames: [String] = []
    var checkedItems: [Bool] = []
    var textValue: String = ""
}

// A completed report (saved locally)
struct Report: Identifiable, Codable {
    var id = UUID()
    var propertyId: UUID?
    var propertyName: String
    var workerName: String
    var workDate: Date
    var entries: [SectionEntry] = []
    var createdAt: Date = Date()
    var pdfFileName: String? // saved PDF file name in Documents
}

// Saved report summary for history list
struct ReportSummary: Identifiable, Codable {
    var id = UUID()
    var propertyName: String
    var workerName: String
    var workDate: Date
    var createdAt: Date
    var pdfFileName: String
    var sectionCount: Int
}

// Runtime photo storage (not Codable - UIImage stored separately)
@Observable
final class ReportDraft {
    var propertyId: UUID?
    var propertyName: String = ""
    var workerName: String = ""
    var workDate: Date = Date()
    var photos: [UUID: [Int?: [UIImage]]] = [:] // sectionId -> floor -> images
    var checks: [UUID: [Bool]] = [:] // sectionId -> checked items
    var texts: [UUID: String] = [:] // sectionId -> text

    func photosFor(sectionId: UUID, floor: Int? = nil) -> [UIImage] {
        photos[sectionId]?[floor] ?? []
    }

    func addPhoto(_ image: UIImage, sectionId: UUID, floor: Int? = nil) {
        if photos[sectionId] == nil { photos[sectionId] = [:] }
        if photos[sectionId]![floor] == nil { photos[sectionId]![floor] = [] }
        photos[sectionId]![floor]!.append(image)
    }

    func removePhoto(sectionId: UUID, floor: Int? = nil, at index: Int) {
        photos[sectionId]?[floor]?.remove(at: index)
    }

    func checksFor(sectionId: UUID, count: Int) -> [Bool] {
        if let existing = checks[sectionId], existing.count == count { return existing }
        let arr = Array(repeating: false, count: count)
        checks[sectionId] = arr
        return arr
    }

    func setCheck(sectionId: UUID, index: Int, value: Bool) {
        checks[sectionId]?[index] = value
    }

    func reset() {
        propertyId = nil
        propertyName = ""
        workDate = Date()
        photos = [:]
        checks = [:]
        texts = [:]
    }
}

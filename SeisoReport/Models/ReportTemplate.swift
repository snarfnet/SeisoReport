import Foundation

// A section in the report template, configurable by admin
struct TemplateSection: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var type: SectionType
    var required: Bool = true
    var note: String = ""
    var checklistItems: [String] = []
    var perFloor: Bool = false // repeat per floor

    enum SectionType: String, Codable, CaseIterable {
        case photo = "photo"
        case checklist = "checklist"
        case text = "text"
    }
}

// A property (building) managed by admin
struct Property: Identifiable, Codable {
    var id = UUID()
    var name: String
    var address: String
    var floors: Int = 3
}

// A registered worker managed by admin
struct Worker: Identifiable, Codable {
    var id = UUID()
    var name: String
    var assignedPropertyIds: [UUID] = []
}

// The full template
struct ReportTemplate: Identifiable, Codable {
    var id = UUID()
    var name: String = "標準テンプレート"
    var sections: [TemplateSection] = Self.defaultSections

    static let defaultSections: [TemplateSection] = [
        TemplateSection(
            title: "物件外観",
            description: "物件の外観（全体）を撮影してください。",
            type: .photo
        ),
        TemplateSection(
            title: "エレベーター清掃",
            description: "エレベーターの掃除をし、清掃後に撮影してください。",
            type: .photo
        ),
        TemplateSection(
            title: "廊下・通路・階段",
            description: "各階の廊下・通路と階段の掃除をし、清掃後に撮影してください。\n※敷地内であることがわかるように撮影してください。",
            type: .photo,
            perFloor: true
        ),
        TemplateSection(
            title: "確認事項",
            description: "",
            type: .checklist,
            checklistItems: [
                "廊下・通路の清掃を実施しましたか",
                "排水溝の清掃を漏れなく実施しましたか",
                "階段部分の清掃を実施しましたか",
            ]
        ),
        TemplateSection(
            title: "ゴミ出し",
            description: "掃除で出たゴミをゴミ置き場（ゴミ箱など）に出してください。",
            type: .photo
        ),
    ]
}

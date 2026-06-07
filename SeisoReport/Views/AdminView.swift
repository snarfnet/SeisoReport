import SwiftUI
import CoreImage.CIFilterBuiltins

struct AdminView: View {
    @Environment(DataStore.self) private var store
    @State private var showQR = false
    @State private var showAddProperty = false
    @State private var newPropertyName = ""
    @State private var newPropertyAddress = ""
    @State private var newPropertyFloors = 3
    @State private var editingSection: TemplateSection?

    var body: some View {
        NavigationStack {
            List {
                propertiesSection
                templateSection
                qrSection
            }
            .navigationTitle("管理者設定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("役割変更") {
                        UserDefaults.standard.removeObject(forKey: "roleSelected")
                        store.setRole(false)
                    }
                }
            }
            .sheet(isPresented: $showAddProperty) { addPropertySheet }
            .sheet(item: $editingSection) { section in
                EditSectionSheet(store: store, section: section)
            }
            .sheet(isPresented: $showQR) { qrSheet }
        }
    }

    // MARK: - Properties

    private var propertiesSection: some View {
        Section {
            ForEach(store.properties) { prop in
                VStack(alignment: .leading, spacing: 4) {
                    Text(prop.name).font(.headline)
                    if !prop.address.isEmpty {
                        Text(prop.address).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(prop.floors)階建て").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                store.properties.remove(atOffsets: offsets)
                store.save()
            }

            Button {
                showAddProperty = true
            } label: {
                Label("物件を追加", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("物件一覧")
        }
    }

    // MARK: - Template

    private var templateSection: some View {
        Section {
            ForEach(store.template.sections) { section in
                Button {
                    editingSection = section
                } label: {
                    HStack {
                        Image(systemName: iconFor(section.type))
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title).foregroundStyle(.primary)
                            Text(section.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if section.perFloor {
                            Text("階別")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15), in: Capsule())
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onMove { from, to in
                store.template.sections.move(fromOffsets: from, toOffset: to)
                store.save()
            }
            .onDelete { offsets in
                store.template.sections.remove(atOffsets: offsets)
                store.save()
            }

            Button {
                let newSection = TemplateSection(
                    title: "新しいセクション",
                    description: "",
                    type: .photo
                )
                store.template.sections.append(newSection)
                store.save()
                editingSection = newSection
            } label: {
                Label("セクションを追加", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("テンプレート")
                Spacer()
                EditButton()
            }
        }
    }

    // MARK: - QR

    private var qrSection: some View {
        Section {
            Button {
                showQR = true
            } label: {
                Label("テンプレートQRコードを表示", systemImage: "qrcode")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text("作業員がこのQRコードを読み取ると、テンプレートと物件情報が同期されます。")
        }
    }

    // MARK: - Sheets

    private var addPropertySheet: some View {
        NavigationStack {
            Form {
                TextField("物件名", text: $newPropertyName)
                TextField("住所", text: $newPropertyAddress)
                Stepper("階数: \(newPropertyFloors)", value: $newPropertyFloors, in: 1...50)
            }
            .navigationTitle("物件追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showAddProperty = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let prop = Property(
                            name: newPropertyName,
                            address: newPropertyAddress,
                            floors: newPropertyFloors
                        )
                        store.properties.append(prop)
                        store.save()
                        newPropertyName = ""
                        newPropertyAddress = ""
                        newPropertyFloors = 3
                        showAddProperty = false
                    }
                    .disabled(newPropertyName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var qrSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let qrImage = generateQRCode() {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                } else {
                    Text("QRコード生成に失敗しました")
                        .foregroundStyle(.red)
                }

                Text("作業員にこのQRコードを読み取ってもらってください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("テンプレートQR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { showQR = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconFor(_ type: TemplateSection.SectionType) -> String {
        switch type {
        case .photo: "camera.fill"
        case .checklist: "checklist"
        case .text: "text.alignleft"
        }
    }

    private func generateQRCode() -> UIImage? {
        // Encode template + properties together
        struct SyncData: Codable {
            let template: ReportTemplate
            let properties: [Property]
        }
        let syncData = SyncData(template: store.template, properties: store.properties)
        guard let jsonData = try? JSONEncoder().encode(syncData) else { return nil }
        let base64 = jsonData.base64EncodedString()

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(base64.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 250.0 / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Edit Section Sheet

private struct EditSectionSheet: View {
    let store: DataStore
    @State var section: TemplateSection
    @Environment(\.dismiss) private var dismiss
    @State private var newChecklistItem = ""

    init(store: DataStore, section: TemplateSection) {
        self.store = store
        self._section = State(initialValue: section)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本設定") {
                    TextField("タイトル", text: $section.title)
                    TextField("説明文", text: $section.description, axis: .vertical)
                        .lineLimit(2...4)

                    Picker("種類", selection: $section.type) {
                        Text("写真").tag(TemplateSection.SectionType.photo)
                        Text("チェックリスト").tag(TemplateSection.SectionType.checklist)
                        Text("テキスト").tag(TemplateSection.SectionType.text)
                    }

                    if section.type == .photo {
                        Toggle("階ごとに繰り返す", isOn: $section.perFloor)
                    }

                    TextField("備考", text: $section.note)
                }

                if section.type == .checklist {
                    Section("チェック項目") {
                        ForEach(Array(section.checklistItems.enumerated()), id: \.offset) { index, item in
                            Text(item)
                        }
                        .onDelete { offsets in
                            section.checklistItems.remove(atOffsets: offsets)
                        }
                        .onMove { from, to in
                            section.checklistItems.move(fromOffsets: from, toOffset: to)
                        }

                        HStack {
                            TextField("新しい項目", text: $newChecklistItem)
                            Button {
                                guard !newChecklistItem.isEmpty else { return }
                                section.checklistItems.append(newChecklistItem)
                                newChecklistItem = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newChecklistItem.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("セクション編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let idx = store.template.sections.firstIndex(where: { $0.id == section.id }) {
                            store.template.sections[idx] = section
                        }
                        store.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

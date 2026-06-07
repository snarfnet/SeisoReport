import SwiftUI
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

struct AdminView: View {
    @Environment(DataStore.self) private var store
    @State private var showAddProperty = false
    @State private var showAddWorker = false
    @State private var editingSection: TemplateSection?
    @State private var editingWorker: Worker?
    @State private var newPropertyName = ""
    @State private var newPropertyAddress = ""
    @State private var newPropertyFloors = 3
    @State private var newWorkerName = ""
    @State private var showBackupShare = false
    @State private var backupURL: URL?
    @State private var showImportPicker = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            List {
                propertiesSection
                workersSection
                templateSection
                backupSection
            }
            .navigationTitle("管理者設定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("役割変更") {
                        store.clearRole()
                    }
                }
            }
            .sheet(isPresented: $showAddProperty) { addPropertySheet }
            .sheet(isPresented: $showAddWorker) { addWorkerSheet }
            .sheet(item: $editingSection) { section in
                EditSectionSheet(store: store, section: section)
            }
            .sheet(item: $editingWorker) { worker in
                WorkerDetailSheet(store: store, worker: worker)
            }
            .sheet(isPresented: $showBackupShare) {
                if let url = backupURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if store.importBackup(from: url) {
                            importMessage = "バックアップを復元しました\n物件: \(store.properties.count)件\n作業員: \(store.workers.count)名"
                        } else {
                            importMessage = "バックアップファイルを読み込めませんでした"
                        }
                    }
                case .failure:
                    importMessage = "ファイルを開けませんでした"
                }
            }
            .alert("復元", isPresented: .init(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK") { importMessage = nil }
            } message: {
                if let msg = importMessage { Text(msg) }
            }
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

    // MARK: - Workers

    private var workersSection: some View {
        Section {
            ForEach(store.workers) { worker in
                Button {
                    editingWorker = worker
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(worker.name)
                                .foregroundStyle(.primary)
                            let propNames = store.properties
                                .filter { worker.assignedPropertyIds.contains($0.id) }
                                .map(\.name)
                            if propNames.isEmpty {
                                Text("担当物件なし")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text(propNames.joined(separator: "、"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onDelete { offsets in
                store.workers.remove(atOffsets: offsets)
                store.save()
            }

            Button {
                showAddWorker = true
            } label: {
                Label("作業員を追加", systemImage: "person.badge.plus")
            }
        } header: {
            Text("作業員")
        } footer: {
            Text("作業員を選ぶと担当物件の設定とQRコード生成ができます。")
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

    private var addWorkerSheet: some View {
        NavigationStack {
            Form {
                TextField("作業員名", text: $newWorkerName)
            }
            .navigationTitle("作業員追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showAddWorker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let worker = Worker(name: newWorkerName)
                        store.workers.append(worker)
                        store.save()
                        newWorkerName = ""
                        showAddWorker = false
                    }
                    .disabled(newWorkerName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Backup

    private var backupSection: some View {
        Section {
            Button {
                backupURL = store.exportBackup()
                if backupURL != nil { showBackupShare = true }
            } label: {
                Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
            }

            Button {
                showImportPicker = true
            } label: {
                Label("バックアップから復元", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("データ管理")
        } footer: {
            Text("テンプレート・物件・作業員データをJSONファイルで保存・復元できます。")
        }
    }

    private func iconFor(_ type: TemplateSection.SectionType) -> String {
        switch type {
        case .photo: "camera.fill"
        case .checklist: "checklist"
        case .text: "text.alignleft"
        }
    }
}

// MARK: - Worker Detail Sheet (assign properties + QR)

private struct WorkerDetailSheet: View {
    let store: DataStore
    @State var worker: Worker
    @State private var showQR = false
    @Environment(\.dismiss) private var dismiss

    init(store: DataStore, worker: Worker) {
        self.store = store
        self._worker = State(initialValue: worker)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("作業員名") {
                    TextField("名前", text: $worker.name)
                }

                Section {
                    if store.properties.isEmpty {
                        Text("物件が登録されていません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.properties) { prop in
                            HStack {
                                let assigned = worker.assignedPropertyIds.contains(prop.id)
                                Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(assigned ? .blue : .secondary)
                                Text(prop.name)
                                Spacer()
                                Text("\(prop.floors)F").font(.caption).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if worker.assignedPropertyIds.contains(prop.id) {
                                    worker.assignedPropertyIds.removeAll { $0 == prop.id }
                                } else {
                                    worker.assignedPropertyIds.append(prop.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("担当物件")
                }

                Section {
                    Button {
                        showQR = true
                    } label: {
                        Label("この作業員のQRコードを表示", systemImage: "qrcode")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(worker.assignedPropertyIds.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(worker.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let idx = store.workers.firstIndex(where: { $0.id == worker.id }) {
                            store.workers[idx] = worker
                        }
                        store.save()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showQR) {
                WorkerQRSheet(store: store, worker: worker)
            }
        }
    }
}

// MARK: - Worker QR Sheet

private struct WorkerQRSheet: View {
    let store: DataStore
    let worker: Worker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(worker.name)
                    .font(.title2.bold())

                if let qrImage = generateQRCode() {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                } else {
                    Text("QRコード生成に失敗しました\n（物件数を減らしてください）")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                let names = assignedProperties.map(\.name)
                VStack(spacing: 4) {
                    Text("担当物件")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("作業員にこのQRコードを読み取ってもらってください")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top)
            }
            .padding()
            .navigationTitle("作業員QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var assignedProperties: [Property] {
        store.properties.filter { worker.assignedPropertyIds.contains($0.id) }
    }

    private func generateQRCode() -> UIImage? {
        struct SyncData: Codable {
            let workerName: String
            let template: ReportTemplate
            let properties: [Property]
        }
        let syncData = SyncData(
            workerName: worker.name,
            template: store.template,
            properties: assignedProperties
        )
        guard let jsonData = try? JSONEncoder().encode(syncData) else { return nil }
        let base64 = jsonData.base64EncodedString()

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(base64.utf8)
        filter.correctionLevel = "L"

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

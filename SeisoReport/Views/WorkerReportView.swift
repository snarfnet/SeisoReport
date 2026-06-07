import SwiftUI
import PhotosUI

struct WorkerReportView: View {
    @Environment(DataStore.self) private var store
    @State private var draft = ReportDraft()
    @State private var showingShare = false
    @State private var pdfURL: URL?
    @State private var showNamePrompt = false

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                templateSections
                submitSection
            }
            .navigationTitle("作業報告")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("役割変更") {
                        store.clearRole()
                    }
                }
            }
            .onAppear {
                draft.workerName = store.workerName
                if store.workerName.isEmpty { showNamePrompt = true }
            }
            .alert("作業者名を入力", isPresented: $showNamePrompt) {
                TextField("名前", text: Binding(
                    get: { draft.workerName },
                    set: { draft.workerName = $0 }
                ))
                Button("OK") {
                    store.workerName = draft.workerName
                    store.save()
                }
            }
            .sheet(isPresented: $showingShare) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var basicInfoSection: some View {
        Section("基本情報") {
            DatePicker("作業日", selection: $draft.workDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))

            if store.properties.isEmpty {
                TextField("物件名", text: $draft.propertyName)
            } else {
                Picker("物件", selection: $draft.propertyId) {
                    Text("選択してください").tag(UUID?.none)
                    ForEach(store.properties) { prop in
                        Text(prop.name).tag(UUID?.some(prop.id))
                    }
                }
                .onChange(of: draft.propertyId) { _, newVal in
                    if let p = store.properties.first(where: { $0.id == newVal }) {
                        draft.propertyName = p.name
                    }
                }
            }

            HStack {
                Text("作業者")
                Spacer()
                Text(draft.workerName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var templateSections: some View {
        ForEach(store.template.sections) { section in
            switch section.type {
            case .photo:
                if section.perFloor {
                    let prop = store.properties.first(where: { $0.id == draft.propertyId })
                    let floors = prop?.floors ?? 3
                    ForEach(stride(from: floors, through: 1, by: -1).map { $0 }, id: \.self) { floor in
                        PhotoSection(
                            title: "\(section.title) \(floor)F",
                            description: section.description,
                            images: draft.photosFor(sectionId: section.id, floor: floor),
                            onAdd: { img in draft.addPhoto(img, sectionId: section.id, floor: floor) },
                            onRemove: { idx in draft.removePhoto(sectionId: section.id, floor: floor, at: idx) }
                        )
                    }
                } else {
                    PhotoSection(
                        title: section.title,
                        description: section.description,
                        images: draft.photosFor(sectionId: section.id),
                        onAdd: { img in draft.addPhoto(img, sectionId: section.id) },
                        onRemove: { idx in draft.removePhoto(sectionId: section.id, at: idx) }
                    )
                }

            case .checklist:
                ChecklistSection(
                    title: section.title,
                    items: section.checklistItems,
                    checks: Binding(
                        get: { draft.checksFor(sectionId: section.id, count: section.checklistItems.count) },
                        set: { draft.checks[section.id] = $0 }
                    )
                )

            case .text:
                Section(section.title) {
                    if !section.description.isEmpty {
                        Text(section.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("入力してください", text: Binding(
                        get: { draft.texts[section.id] ?? "" },
                        set: { draft.texts[section.id] = $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
        }
    }

    private var submitSection: some View {
        Section {
            Button {
                generateAndShare()
            } label: {
                Label("報告書を送信", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func generateAndShare() {
        let prop = store.properties.first(where: { $0.id == draft.propertyId })
            ?? Property(name: draft.propertyName, address: "", floors: 3)

        let data = PDFGenerator.generate(
            template: store.template,
            draft: draft,
            property: prop
        )

        // Save to history and get file URL
        let url = store.saveReport(
            pdfData: data,
            draft: draft,
            sectionCount: store.template.sections.count
        )
        pdfURL = url
        showingShare = true
    }
}

// MARK: - Photo Section

private struct PhotoSection: View {
    let title: String
    let description: String
    var images: [UIImage]
    let onAdd: (UIImage) -> Void
    let onRemove: (Int) -> Void

    @State private var showCamera = false
    @State private var showPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        Section {
            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !images.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    onRemove(index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .red)
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("撮影", systemImage: "camera.fill")
                }
                .buttonStyle(.borderless)

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                    Label("選択", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.borderless)
                .onChange(of: selectedItems) { _, items in
                    for item in items {
                        item.loadTransferable(type: Data.self) { result in
                            if case .success(let data) = result, let data, let img = UIImage(data: data) {
                                DispatchQueue.main.async { onAdd(img) }
                            }
                        }
                    }
                    selectedItems = []
                }
            }
        } header: {
            Text(title)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { img in
                if let img { onAdd(img) }
            }
        }
    }
}

// MARK: - Checklist Section

private struct ChecklistSection: View {
    let title: String
    let items: [String]
    @Binding var checks: [Bool]

    var body: some View {
        Section(title) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Toggle(item, isOn: Binding(
                    get: { index < checks.count && checks[index] },
                    set: { val in
                        while checks.count <= index { checks.append(false) }
                        checks[index] = val
                    }
                ))
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

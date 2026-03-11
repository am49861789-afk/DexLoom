import SwiftUI

struct ResourceInspectorView: View {
    @ObservedObject var bridge: RuntimeBridge
    @State private var searchText = ""
    @State private var resolution: ResourceResolution?
    @State private var allEntries: [ResourceEntry] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var filterType = "All"

    private let typeFilters = ["All", "string", "color", "dimen", "integer", "bool", "reference"]

    var body: some View {
        NavigationStack {
            Group {
                if !bridge.isLoaded {
                    emptyState
                } else {
                    resourceContent
                }
            }
            .navigationTitle("Resources")
            .onAppear {
                if bridge.isLoaded && allEntries.isEmpty {
                    loadEntries()
                }
            }
            .onChange(of: bridge.isLoaded) {
                if bridge.isLoaded {
                    loadEntries()
                } else {
                    allEntries = []
                    resolution = nil
                    hasSearched = false
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.dxTextSecondary)
            Text("No APK Loaded")
                .font(.dxHeadline)
                .foregroundStyle(Color.dxText)
            Text("Load an APK from the Home tab to inspect its resources.")
                .font(.dxCaption)
                .foregroundStyle(Color.dxTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dxBackground)
    }

    private var resourceContent: some View {
        VStack(spacing: 0) {
            // Resource ID lookup
            lookupSection

            Divider()
                .background(Color.dxTextSecondary.opacity(0.3))

            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(typeFilters, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            Text(type)
                                .font(.system(size: 12, weight: filterType == type ? .bold : .regular, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(filterType == type ? Color.dxPrimary.opacity(0.2) : Color.dxSurface)
                                .foregroundStyle(filterType == type ? Color.dxPrimary : Color.dxTextSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Resource list
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.dxTextSecondary)
                    Text("No resources found")
                        .font(.dxBody)
                        .foregroundStyle(Color.dxTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dxBackground)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        ResourceEntryRow(entry: entry)
                            .listRowBackground(Color.dxSurface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.dxBackground)
            }
        }
        .background(Color.dxBackground)
    }

    private var lookupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Resource Lookup", systemImage: "magnifyingglass")
                .font(.dxHeadline)
                .foregroundStyle(Color.dxText)

            HStack {
                TextField("Resource ID (e.g., 0x7f0e0001)", text: $searchText)
                    .font(.dxCode)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Resolve") {
                    resolveResourceId()
                }
                .font(.dxBody)
                .buttonStyle(.borderedProminent)
                .tint(Color.dxPrimary)
                .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if hasSearched {
                if let resolution = resolution {
                    resolutionDetail(resolution)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(Color.dxError)
                        Text("Resource not found for the given ID.")
                            .font(.dxCaption)
                            .foregroundStyle(Color.dxError)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func resolutionDetail(_ res: ResourceResolution) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Resolution Chain")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.dxSecondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                resolutionRow("ID", String(format: "0x%08X", res.resourceId))
                resolutionRow("Type", res.type)
                resolutionRow("Qualifiers", res.qualifiers)
                resolutionRow("Config", res.configUsed)

                Divider()
                    .background(Color.dxTextSecondary.opacity(0.3))

                HStack(alignment: .top) {
                    Text("Value")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.dxTextSecondary)
                        .frame(width: 70, alignment: .leading)
                    Text(res.resolvedValue)
                        .font(.dxCode)
                        .foregroundStyle(Color.dxPrimary)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(Color.dxSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func resolutionRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.dxTextSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.dxText)
                .textSelection(.enabled)
        }
    }

    private var filteredEntries: [ResourceEntry] {
        let entries: [ResourceEntry]
        if filterType == "All" {
            entries = allEntries
        } else {
            entries = allEntries.filter { $0.type == filterType }
        }
        return entries
    }

    private func resolveResourceId() {
        let text = searchText.trimmingCharacters(in: .whitespaces)
        hasSearched = true

        // Parse hex or decimal
        let resourceId: UInt32
        if text.lowercased().hasPrefix("0x") {
            let hex = String(text.dropFirst(2))
            guard let val = UInt32(hex, radix: 16) else {
                resolution = nil
                return
            }
            resourceId = val
        } else {
            guard let val = UInt32(text) else {
                resolution = nil
                return
            }
            resourceId = val
        }

        resolution = bridge.resolveResource(id: resourceId)
    }

    private func loadEntries() {
        isLoading = true
        allEntries = bridge.getAllResourceEntries()
        isLoading = false
    }
}

// MARK: - Resource Entry Row

struct ResourceEntryRow: View {
    let entry: ResourceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.dxCode)
                    .foregroundStyle(Color.dxText)
                    .lineLimit(1)

                Spacer()

                Text(entry.type)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor(entry.type).opacity(0.15))
                    .foregroundStyle(typeColor(entry.type))
                    .clipShape(Capsule())
            }

            HStack {
                Text(String(format: "0x%08X", entry.resourceId))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.dxTextSecondary)

                Text("|")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dxTextSecondary.opacity(0.5))

                Text(entry.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.dxPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "string": return Color.dxSecondary
        case "color": return Color.dxWarning
        case "dimen": return Color.dxPrimary
        case "integer", "integer-hex": return Color.dxText
        case "bool": return Color.dxError
        case "reference": return Color.dxTextSecondary
        default: return Color.dxTextSecondary
        }
    }
}

import SwiftUI

/// The Layers panel's type filter: the kinds of layer the list narrows to while their toggles are on.
enum LayerType: String, CaseIterable {
    case image, shape, text, folder, adjustment
}

extension LayerType {
    var titleKey: LocalizedStringKey {
        switch self {
        case .image: "Images"
        case .shape: "Shapes"
        case .text: "Text"
        case .folder: "Folders"
        case .adjustment: "Adjustments"
        }
    }
    var systemImageName: String {
        switch self {
        case .image: "photo"
        case .shape: "square.on.circle"
        case .text: "character"
        case .folder: "folder"
        case .adjustment: "circle.righthalf.filled"
        }
    }
    /// VoiceOver's description of the type's toggle.
    var filterLabel: LocalizedStringKey {
        switch self {
        case .image: "Filter to image layers"
        case .shape: "Filter to shape layers"
        case .text: "Filter to text layers"
        case .folder: "Filter to folder layers"
        case .adjustment: "Filter to adjustment layers"
        }
    }
    /// The toggle's stable identifier, cased to match "layerFilterAll".
    var accessibilityID: String {
        "layerFilter" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

extension ImageLayer {
    /// Which of the panel's type filters the layer belongs to. Text means editable text; rasterized
    /// text counts as an image, as it does everywhere else in the app.
    var layerType: LayerType {
        if isGroup { return .folder }
        if adjustment != nil { return .adjustment }
        if liveText != nil { return .text }
        if shape != nil { return .shape }
        return .image
    }
}

extension EditorSession {
    /// Whether the panel's search text or type filter is on.
    var isFilteringLayers: Bool { !layerSearchText.isEmpty || !layerTypeFilter.isEmpty }
    /// The rows the panel shows: `layerRows` narrowed by the search text and type filter. While a filter
    /// is on, folders list themselves opened, so layers inside collapsed folders can be found too.
    var filteredLayerRows: [LayerHierarchy.Entry] {
        let entries = LayerHierarchy.entries(document?.layers.map(\.hierarchyRecord) ?? [], topFirst: true,
                                             collapsed: isFilteringLayers ? [] : collapsedGroupIDs)
        guard isFilteringLayers else { return entries }
        let query = layerSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        let byID = Dictionary(uniqueKeysWithValues: (document?.layers ?? []).map { ($0.id, $0) })
        return entries.filter { entry in
            guard let layer = byID[entry.layer.id] else { return false }
            return (query.isEmpty || layer.name.lowercased().contains(query))
                && (layerTypeFilter.isEmpty || layerTypeFilter.contains(layer.layerType))
        }
    }
    /// Clears the panel's search text.
    func clearLayerSearch() {
        layerSearchText = ""
    }
    /// Clears the panel's every type toggle.
    func clearLayerTypeFilter() {
        layerTypeFilter = []
    }
}

/// The Layers panel's title row: "Layers", with a magnifier that turns the title into a search field for layer names,
/// and a funnel that opens the type filter (blue while one is on). The search stays open while it has text; Escape
/// or clicking away with nothing typed puts the title back.
struct LayersHeader: View {
    @Bindable var session: EditorSession
    @State private var searching = false
    /// Whether the funnel's type-filter panel is open.
    @State private var isPresentingFilter = false

    var body: some View {
        HStack(spacing: 10) {
            if searching || !session.layerSearchText.isEmpty {
                LayerSearchField(text: $session.layerSearchText) { searching = false }
            } else {
                Text("Layers").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { searching = true } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Search layers by name").accessibilityLabel("Search layers")
                    .accessibilityIdentifier("layerSearchButton")
            }
            Button { isPresentingFilter.toggle() } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(session.layerTypeFilter.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
            }
            .buttonStyle(.plain)
            .help("Show only some kinds of layer").accessibilityLabel("Filter the layer list")
            .popover(isPresented: $isPresentingFilter) { typeFilterPopover }
        }
        .frame(height: 22)
        .padding(.horizontal, 18).padding(.vertical, 14)
        .disabled(session.document?.layers.isEmpty != false)
    }

    /// The funnel's contents. All Layers and Clear All concern the type toggles alone — the search
    /// field brings its own clear button — so All Layers reads as on while no toggle is on, and
    /// Clear All is enabled only while one is.
    private var typeFilterPopover: some View {
        VStack(alignment: .leading) {
            Toggle("All Layers", systemImage: "square.3.layers.3d", isOn: Binding(
                get: { session.layerTypeFilter.isEmpty },
                set: { on in if on { session.clearLayerTypeFilter() } }
            ))
            .labelReservedIconWidth(16)
            .accessibilityIdentifier("layerFilterAll")
            Divider()
            ForEach(LayerType.allCases, id: \.self) { typeToggle($0) }
            Divider()
            Button("Clear All") { session.clearLayerTypeFilter() }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(session.layerTypeFilter.isEmpty)
        }
        .padding()
    }

    private func typeToggle(_ kind: LayerType) -> some View {
        Toggle(kind.titleKey, systemImage: kind.systemImageName, isOn: Binding(
            get: { session.layerTypeFilter.contains(kind) },
            set: { on in if on { session.layerTypeFilter.insert(kind) } else { session.layerTypeFilter.remove(kind) } }
        ))
        .labelReservedIconWidth(16)
        .accessibilityLabel(kind.filterLabel)
        .accessibilityIdentifier(kind.accessibilityID)
    }
}

/// The Layers panel's search field: AppKit's search field, which brings its own clear button and clears on Escape.
/// It takes the keyboard when it appears; `end` runs once it's left empty, by Escape or a click elsewhere.
private struct LayerSearchField: NSViewRepresentable {
    @Binding var text: String
    var end: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search Layers"
        field.controlSize = .small
        field.delegate = context.coordinator
        field.setAccessibilityIdentifier("layerSearch")
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        // Only when they differ: writing the string back mid-edit would move the insertion point.
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, end: end) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let text: Binding<String>
        let end: () -> Void
        init(text: Binding<String>, end: @escaping () -> Void) { self.text = text; self.end = end }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if text.wrappedValue.isEmpty { end() }
        }

        /// Escape clears the search; on an empty one it closes it and gives the canvas back the keyboard.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)), text.wrappedValue.isEmpty else { return false }
            control.window?.makeFirstResponder(nil)
            end()
            return true
        }
    }
}

import SwiftUI
import AppKit

struct Node: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var isSelected: Bool = false
    let isFolder: Bool
    var children: [Node]? = nil
}

@MainActor
class InstallerViewModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var isAnalyzing: Bool = false
    @Published var isInstalling: Bool = false
    @Published var isShowingSettings: Bool = false
    @Published var sources: [String] = []
    
    private let registryURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/antigravity/registry.json")
    }()
    
    init() {
        loadSources()
        // Mock data representing the Hub structure (эталон)
        nodes = [
            Node(name: "skills", isFolder: true, children: [
                Node(name: "ai", isFolder: true, children: [Node(name: "agents", isFolder: false), Node(name: "mcp", isFolder: false)]),
                Node(name: "backend", isFolder: true, children: [Node(name: "nodejs", isFolder: false), Node(name: "python", isFolder: false), Node(name: "rust", isFolder: false)]),
                Node(name: "database", isFolder: true, children: [Node(name: "prisma", isFolder: false)]),
                Node(name: "design", isFolder: true, children: [Node(name: "ui", isFolder: false)]),
                Node(name: "devops", isFolder: true, children: [Node(name: "ci-cd", isFolder: false), Node(name: "docker", isFolder: false)]),
                Node(name: "frontend", isFolder: true, children: [Node(name: "nextjs", isFolder: false), Node(name: "react", isFolder: false), Node(name: "tailwind", isFolder: false)]),
                Node(name: "native", isFolder: true, children: [Node(name: "tauri", isFolder: false), Node(name: "apple", isFolder: false)]),
                Node(name: "testing", isFolder: true, children: [Node(name: "e2e", isFolder: false), Node(name: "unit", isFolder: false)])
            ]),
            Node(name: "global_workflows", isFolder: true, children: [
                Node(name: "arch-evolution.md", isFolder: false),
                Node(name: "db-migration-engine.md", isFolder: false),
                Node(name: "feature-pipeline.md", isFolder: false),
                Node(name: "qa-orchestrator.md", isFolder: false),
                Node(name: "init-project.md", isFolder: false)
            ])
        ]
    }
    
    func analyzeSystem() {
        isAnalyzing = true
        // Симулируем анализ локальной системы (парсинг package.json, Cargo.toml и т.д.)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Например, анализатор нашел React и Tailwind в открытом проекте:
            self.toggleSelection(for: "react")
            self.toggleSelection(for: "tailwind")
            self.toggleSelection(for: "feature-pipeline.md")
            self.isAnalyzing = false
        }
    }
    
    func installSelected() {
        isInstalling = true
        // Симулируем скачивание выбранных чекбоксов в ~/.gemini/antigravity/
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isInstalling = false
        }
    }
    
    private func toggleSelection(for target: String) {
        func searchAndToggle(in nodes: inout [Node]) -> Bool {
            var found = false
            for i in 0..<nodes.count {
                if nodes[i].name == target {
                    nodes[i].isSelected = true
                    found = true
                }
                if nodes[i].children != nil {
                    var children = nodes[i].children!
                    if searchAndToggle(in: &children) {
                        nodes[i].children = children
                        found = true
                    }
                }
            }
            return found
        }
        _ = searchAndToggle(in: &nodes)
    }
    
    // MARK: - Registry Persistence
    
    func loadSources() {
        do {
            if FileManager.default.fileExists(atPath: registryURL.path) {
                let data = try Data(contentsOf: registryURL)
                if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let loadedSources = dict["sources"] as? [String] {
                    self.sources = loadedSources
                }
            }
        } catch {
            print("Failed to load registry: \(error)")
        }
    }
    
    func saveSources() {
        do {
            let dict: [String: Any] = ["sources": sources]
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            try data.write(to: registryURL)
        } catch {
            print("Failed to save registry: \(error)")
        }
    }
}

struct InstallerView: View {
    @StateObject private var viewModel = InstallerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    Text("AI Ecosystem Installer")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Analyze your active project to globally install missing AI skills.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                
                Button(action: {
                    viewModel.isShowingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content List
            List {
                ForEach($viewModel.nodes) { $node in
                    NodeView(node: $node)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Footer
            HStack {
                Button(action: {
                    viewModel.analyzeSystem()
                }) {
                    HStack {
                        if viewModel.isAnalyzing {
                            ProgressView().controlSize(.small).padding(.trailing, 2)
                            Text("Analyzing Stack...")
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Analyze System")
                        }
                    }
                }
                .disabled(viewModel.isAnalyzing || viewModel.isInstalling)
                
                Spacer()
                
                Button(action: {
                    viewModel.installSelected()
                }) {
                    HStack {
                        if viewModel.isInstalling {
                            ProgressView().controlSize(.small).padding(.trailing, 2)
                            Text("Installing...")
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("Install Selected")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(viewModel.isAnalyzing || viewModel.isInstalling)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SourcesSettingsView(viewModel: viewModel)
        }
    }
}

struct NodeView: View {
    @Binding var node: Node
    
    var body: some View {
        if node.isFolder {
            DisclosureGroup {
                if let children = node.children {
                    ForEach(Binding(get: { children }, set: { node.children = $0 })) { $child in
                        NodeView(node: $child)
                    }
                }
            } label: {
                Label(node.name, systemImage: "folder.fill")
                    .foregroundColor(.primary)
            }
        } else {
            Toggle(isOn: $node.isSelected) {
                Label(node.name, systemImage: "doc.text")
            }
            .toggleStyle(.checkbox)
        }
    }
}

struct SourcesSettingsView: View {
    @ObservedObject var viewModel: InstallerViewModel
    @State private var newSource: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Registry Sources")
                .font(.headline)
            
            Text("The installer will fetch skills and workflows from these GitHub repositories.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            List {
                ForEach(viewModel.sources, id: \.self) { source in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                        Text(source)
                        Spacer()
                        Button(action: {
                            viewModel.sources.removeAll { $0 == source }
                            viewModel.saveSources()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 150)
            .border(Color.secondary.opacity(0.2), width: 1)
            
            HStack {
                TextField("https://github.com/...", text: $newSource)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    if !newSource.isEmpty {
                        viewModel.sources.append(newSource)
                        viewModel.saveSources()
                        newSource = ""
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Done") {
                    viewModel.isShowingSettings = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450)
    }
}

import SwiftUI
import AppKit

struct Node: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var isSelected: Bool = false
    let isFolder: Bool
    var children: [Node]? = nil
}

struct RegistrySection: Identifiable, Codable {
    var id: String { title }
    var title: String
    var isEnabled: Bool
    var repositories: [String]
}

enum InstallerStep {
    case initial
    case analyzing
    case results
    case installing
}

@MainActor
class InstallerViewModel: ObservableObject {
    @Published var step: InstallerStep = .initial
    @Published var nodes: [Node] = []
    @Published var isShowingSettings: Bool = false
    @Published var registrySections: [RegistrySection] = []
    @Published var systemReport: SystemReport? = nil
    
    private var registryURL: URL {
        return AntigravityAPI.shared.baseDir.appendingPathComponent("registry.json")
    }
    
    init() {
        loadSources()
    }
    
    func analyzeSystem() {
        step = .analyzing
        
        DispatchQueue.global(qos: .userInitiated).async {
            let report = SystemAnalyzer.analyze()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.systemReport = report
                
                var rootNodes: [Node] = []
                
                // 1. Core Ecosystem (always offer)
                rootNodes.append(Node(name: "core_antigravity", isFolder: true, children: [
                    Node(name: "antigravity-awesome-skills", isSelected: !report.hasAntigravity, isFolder: false),
                    Node(name: "claude-code-system-prompts", isSelected: true, isFolder: false)
                ]))
                
                // 2. Conditional Projects
                var skillsChildren: [Node] = []
                
                if report.foundProjects.contains("Node/React") {
                    skillsChildren.append(Node(name: "frontend", isFolder: true, children: [
                        Node(name: "react", isFolder: true, children: [
                            Node(name: "react-expert.md", isSelected: true, isFolder: false),
                            Node(name: "hooks-patterns.md", isSelected: true, isFolder: false)
                        ]),
                        Node(name: "tailwind", isFolder: true, children: [
                            Node(name: "tailwind-best-practices.md", isSelected: true, isFolder: false)
                        ])
                    ]))
                }
                
                if report.foundProjects.contains("Rust/Tauri") {
                    skillsChildren.append(Node(name: "backend", isFolder: true, children: [
                        Node(name: "rust", isFolder: true, children: [
                            Node(name: "rust-memory-safety.md", isSelected: true, isFolder: false)
                        ])
                    ]))
                }
                
                // 3. Apple MLX
                skillsChildren.append(Node(name: "native", isFolder: true, children: [
                    Node(name: "apple", isFolder: true, children: [
                        Node(name: "apple-mlx.md", isSelected: false, isFolder: false)
                    ])
                ]))
                
                if !skillsChildren.isEmpty {
                    rootNodes.append(Node(name: "skills", isFolder: true, children: skillsChildren))
                }
                
                // 4. Global Workflows
                rootNodes.append(Node(name: "global_workflows", isFolder: true, children: [
                    Node(name: "feature-pipeline.md", isSelected: true, isFolder: false),
                    Node(name: "qa-orchestrator.md", isSelected: true, isFolder: false)
                ]))
                
                self.nodes = rootNodes
                self.step = .results
            }
        }
    }
    
    func installSelected() {
        step = .installing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.step = .initial
        }
    }
    
    // MARK: - Registry Persistence
    func loadSources() {
        do {
            if FileManager.default.fileExists(atPath: registryURL.path) {
                let data = try Data(contentsOf: registryURL)
                // Если старый плоский формат - оборачиваем в секции
                if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let loadedSources = dict["sources"] as? [String] {
                    self.registrySections = [
                        RegistrySection(title: "🌌 All Ecosystem Hubs", isEnabled: true, repositories: loadedSources)
                    ]
                } else if let loaded = try? JSONDecoder().decode([RegistrySection].self, from: data) {
                    self.registrySections = loaded
                }
            }
        } catch {
            print("Failed to load registry: \(error)")
        }
        
        if self.registrySections.isEmpty {
            self.registrySections = [
                RegistrySection(title: "🌌 Core Antigravity", isEnabled: true, repositories: ["https://github.com/sickn33/antigravity-awesome-skills"])
            ]
        }
    }
    
    func saveSources() {
        do {
            let data = try JSONEncoder().encode(registrySections)
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
            
            // Dynamic Content
            VStack {
                switch viewModel.step {
                case .initial:
                    Spacer()
                    Button(action: {
                        viewModel.analyzeSystem()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("Analyze System")
                                .font(.headline)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    Spacer()
                    
                case .analyzing:
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing standard places and projects...")
                            .font(.headline)
                        Text("Fetching remote repositories and resolving context.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                case .results:
                    VStack(alignment: .leading, spacing: 0) {
                        // Analysis Report
                        VStack(alignment: .leading, spacing: 8) {
                            if let report = viewModel.systemReport {
                                if report.warnings.isEmpty {
                                    Text("System is healthy.")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                } else {
                                    Text("System Alerts:")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    ForEach(report.warnings, id: \.self) { warning in
                                        Text("• \(warning)")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                }
                                
                                if !report.foundProjects.isEmpty {
                                    Text("Detected Stack: \(report.foundProjects.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        
                        List {
                            ForEach($viewModel.nodes) { $node in
                                NodeView(node: $node)
                            }
                        }
                        .listStyle(.sidebar)
                    }
                    
                case .installing:
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Installing Skills...")
                            .font(.headline)
                        Text("Injecting selected configurations into \(AntigravityAPI.shared.baseDir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))/")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer
            if viewModel.step == .results {
                Divider()
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.installSelected()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Install Selected")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 500, idealWidth: 500, minHeight: 450, idealHeight: 600)
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
            
            Text("Toggle groups to optimize your context window. Only enabled groups will be fetched.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            List {
                ForEach(viewModel.registrySections.indices, id: \.self) { index in
                    Section(header: HStack {
                        Toggle("", isOn: Binding(
                            get: { viewModel.registrySections[index].isEnabled },
                            set: { newValue in
                                viewModel.registrySections[index].isEnabled = newValue
                                viewModel.saveSources()
                            }
                        ))
                        .labelsHidden()
                        
                        Text(viewModel.registrySections[index].title)
                            .font(.headline)
                            .foregroundColor(viewModel.registrySections[index].isEnabled ? .primary : .secondary)
                    }) {
                        if viewModel.registrySections[index].isEnabled {
                            ForEach(viewModel.registrySections[index].repositories, id: \.self) { repo in
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.purple)
                                    Text(repo)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        viewModel.registrySections[index].repositories.removeAll { $0 == repo }
                                        viewModel.saveSources()
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 250)
            .border(Color.secondary.opacity(0.2), width: 1)
            
            HStack {
                TextField("https://github.com/...", text: $newSource)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add to First Group") {
                    if !newSource.isEmpty, !viewModel.registrySections.isEmpty {
                        viewModel.registrySections[0].repositories.append(newSource)
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
        .frame(width: 550)
    }
}

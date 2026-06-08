import Foundation

/// Indexes a flat list of declarations by qualified name, simple name within
/// a module, and simple name globally. Multiple declarations may share a
/// simple name; the table preserves all candidates and exposes ambiguity.
public struct SymbolTable {
    /// dotted qualified name -> ids (usually one, but typealiases /
    /// extensions can collide on `qualifiedName.dotted`).
    private let byDotted: [String: [TypeDeclaration.ID]]
    /// (module, simpleName) -> ids
    private let byModuleSimple: [String: [String: [TypeDeclaration.ID]]]
    /// simpleName -> ids (any module)
    private let bySimple: [String: [TypeDeclaration.ID]]
    /// id -> module (for quick reverse lookups).
    public let moduleOf: [TypeDeclaration.ID: String]
    /// All known module names.
    public let modules: Set<String>

    public init(declarations: [TypeDeclaration]) {
        var byDotted: [String: [TypeDeclaration.ID]] = [:]
        var byModuleSimple: [String: [String: [TypeDeclaration.ID]]] = [:]
        var bySimple: [String: [TypeDeclaration.ID]] = [:]
        var moduleOf: [TypeDeclaration.ID: String] = [:]
        var modules: Set<String> = []

        for decl in declarations {
            let dotted = decl.qualifiedName.dotted
            byDotted[dotted, default: []].append(decl.id)
            bySimple[decl.qualifiedName.name, default: []].append(decl.id)
            if let module = decl.qualifiedName.module {
                modules.insert(module)
                moduleOf[decl.id] = module
                byModuleSimple[module, default: [:]][decl.qualifiedName.name, default: []].append(decl.id)
            }
        }
        self.byDotted = byDotted
        self.byModuleSimple = byModuleSimple
        self.bySimple = bySimple
        self.moduleOf = moduleOf
        self.modules = modules
    }

    public func candidates(simple: String, inModule module: String?) -> [TypeDeclaration.ID] {
        if let module = module,
           let inModule = byModuleSimple[module]?[simple], !inModule.isEmpty {
            return inModule
        }
        return bySimple[simple] ?? []
    }

    public func candidates(qualified: QualifiedName) -> [TypeDeclaration.ID] {
        if let exact = byDotted[qualified.dotted] { return exact }
        // Fallback: ignore the optional module and try parents + name match.
        let stripped = QualifiedName(module: nil,
                                     parents: qualified.parents,
                                     name: qualified.name)
        if let viaStripped = byDotted[stripped.dotted] { return viaStripped }
        return []
    }

    public func candidatesAnyKind(simple: String) -> [TypeDeclaration.ID] {
        bySimple[simple] ?? []
    }

    public func isAmbiguous(simple: String, inModule module: String?) -> Bool {
        candidates(simple: simple, inModule: module).count > 1
    }
}

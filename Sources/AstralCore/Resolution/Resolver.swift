import Foundation

/// Resolves the candidate qualified names on each `TypeReference` to
/// declaration ids using a lexical, name-based strategy.
///
/// Resolution order per reference:
///   1. Walk the owner's parent chain inside its module for a matching
///      nested declaration.
///   2. Same module by simple name.
///   3. Same-file imports (modules in the file's `imports` set).
///   4. Any module by simple name.
/// If no candidates remain and the name is not in `KnownExternalTypes`,
/// the reference is added to the unresolved bucket.
public struct Resolver {
    public let table: SymbolTable
    public let fileImports: [String: Set<String>]
    public let includeStdlibRefs: Bool

    public init(table: SymbolTable,
                fileImports: [String: Set<String>] = [:],
                includeStdlibRefs: Bool = false) {
        self.table = table
        self.fileImports = fileImports
        self.includeStdlibRefs = includeStdlibRefs
    }

    public struct Output {
        public let resolvedEdges: [DependencyEdge]
        public let unresolvedReferences: [TypeReference]
    }

    public func resolve(edges: [DependencyEdge],
                        declarations: [TypeDeclaration]) -> Output {
        // Tolerate duplicate ids defensively (e.g. typealiases or nested types
        // with colliding qualified-name+kind); first occurrence wins.
        let declById: [TypeDeclaration.ID: TypeDeclaration] =
            Dictionary(declarations.map { ($0.id, $0) },
                       uniquingKeysWith: { first, _ in first })
        var resolved: [DependencyEdge] = []
        resolved.reserveCapacity(edges.count)
        var unresolved: [TypeReference] = []

        for edge in edges {
            let owner = declById[edge.fromId]
            let candidates = resolveReference(edge.to, owner: owner)
            if candidates.isEmpty {
                let leaf = leafName(of: edge.to)
                if !KnownExternalTypes.isKnown(leaf) || includeStdlibRefs {
                    unresolved.append(edge.to)
                }
            }
            resolved.append(DependencyEdge(
                id: edge.id,
                fromId: edge.fromId,
                to: edge.to,
                resolvedToIds: candidates,
                kind: edge.kind,
                location: edge.location,
                condition: edge.condition
            ))
        }
        return Output(resolvedEdges: resolved, unresolvedReferences: unresolved)
    }

    // MARK: - Per-reference resolution

    func resolveReference(_ ref: TypeReference,
                          owner: TypeDeclaration?) -> [TypeDeclaration.ID] {
        // 1) Try every candidate qualified name that already carries parents.
        for qn in ref.candidateQualifiedNames where !qn.parents.isEmpty || qn.module != nil {
            let hits = table.candidates(qualified: qn)
            if !hits.isEmpty { return hits.sorted() }
        }

        // 2) Lexical resolution by simple name. We use the leaf as the name to search.
        let leaf = leafName(of: ref)

        // 2a) Owner's parent chain (nested type lookup).
        if let owner = owner {
            let parents = owner.qualifiedName.parents + [owner.qualifiedName.name]
            for depth in stride(from: parents.count, through: 0, by: -1) {
                let chain = Array(parents.prefix(depth))
                let qn = QualifiedName(module: owner.qualifiedName.module,
                                       parents: chain, name: leaf)
                let hits = table.candidates(qualified: qn)
                if !hits.isEmpty { return hits.sorted() }
            }
        }

        // 2b) Same module top-level by simple name.
        if let module = owner?.qualifiedName.module {
            let inModule = table.candidates(simple: leaf, inModule: module)
            if !inModule.isEmpty { return inModule.sorted() }
        }

        // 2c) Same-file imports.
        if let owner = owner {
            let importedModules = fileImports[owner.location.file] ?? []
            var imported: [TypeDeclaration.ID] = []
            for mod in importedModules {
                imported.append(contentsOf: table.candidates(simple: leaf, inModule: mod))
            }
            if !imported.isEmpty { return Array(Set(imported)).sorted() }
        }

        // 2d) Any module (global fallback).
        let global = table.candidatesAnyKind(simple: leaf)
        if !global.isEmpty { return global.sorted() }

        return []
    }

    private func leafName(of ref: TypeReference) -> String {
        if let firstWithParents = ref.candidateQualifiedNames.first(where: { !$0.parents.isEmpty }) {
            return firstWithParents.name
        }
        return ref.candidateQualifiedNames.last?.name ?? ref.rawText
    }
}

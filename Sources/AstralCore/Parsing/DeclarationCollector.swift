import Foundation
import SwiftSyntax

/// Walks a parsed source file and emits one `TypeDeclaration` per
/// type-like declaration node (protocol, class, struct, enum, actor,
/// typealias, extension), recording its parent chain and nested children.
public final class DeclarationCollector: SyntaxVisitor {
    public private(set) var declarations: [TypeDeclaration] = []

    private let module: String
    private let file: URL
    private let converter: SourceLocationConverter

    private var parentStack: [String] = []
    /// Indices into `declarations` for each open scope. The outermost
    /// sentinel (root, no decl) sits at index 0.
    private var scopeIndexStack: [Int?] = [nil]
    /// Nested-decl ids accumulated for each open scope.
    private var nestedIdsStack: [[TypeDeclaration.ID]] = [[]]

    public init(parsedFile: ParsedFile) {
        self.module = parsedFile.moduleName
        self.file = parsedFile.url
        self.converter = parsedFile.locationConverter
        super.init(viewMode: .sourceAccurate)
    }

    public func collect(_ syntax: SourceFileSyntax) -> [TypeDeclaration] {
        declarations.removeAll(keepingCapacity: true)
        parentStack.removeAll(keepingCapacity: true)
        scopeIndexStack = [nil]
        nestedIdsStack = [[]]
        walk(syntax)
        return declarations
    }

    // MARK: - Nominal type visits

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.struct, name: node.name.text, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: node.genericParameterClause,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: StructDeclSyntax) { leave() }

    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.class, name: node.name.text, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: node.genericParameterClause,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: ClassDeclSyntax) { leave() }

    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.enum, name: node.name.text, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: node.genericParameterClause,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: EnumDeclSyntax) { leave() }

    public override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.actor, name: node.name.text, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: node.genericParameterClause,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: ActorDeclSyntax) { leave() }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.protocol, name: node.name.text, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: nil,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: ProtocolDeclSyntax) { leave() }

    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let nameText = node.extendedType.trimmedDescription
        enter(.extension, name: nameText, node: Syntax(node),
              inheritance: node.inheritanceClause,
              generics: nil,
              whereClause: node.genericWhereClause,
              members: node.memberBlock)
        return .visitChildren
    }
    public override func visitPost(_ node: ExtensionDeclSyntax) { leave() }

    public override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(.typealias, name: node.name.text, node: Syntax(node),
              inheritance: nil,
              generics: node.genericParameterClause,
              whereClause: node.genericWhereClause,
              members: nil)
        return .visitChildren
    }
    public override func visitPost(_ node: TypeAliasDeclSyntax) { leave() }

    // MARK: - Internals

    private func enter(_ kind: TypeKind,
                       name: String,
                       node: Syntax,
                       inheritance: InheritanceClauseSyntax?,
                       generics: GenericParameterClauseSyntax?,
                       whereClause: GenericWhereClauseSyntax?,
                       members: MemberBlockSyntax?) {
        let qn = QualifiedName(module: module, parents: parentStack, name: name)
        let location = makeLocation(of: node)
        let id: TypeDeclaration.ID = (kind == .extension)
            ? TypeDeclaration.makeExtensionId(qualifiedName: qn, location: location)
            : TypeDeclaration.makeId(qualifiedName: qn, kind: kind)

        let inherited = (inheritance?.inheritedTypes ?? []).map { $0.type.trimmedDescription }
        let genericParams = (generics?.parameters ?? []).map { $0.name.text }
        let constraints = (whereClause?.requirements ?? []).map { $0.requirement.trimmedDescription }
        let summary = members.map { Self.summarize($0) } ?? .init()

        let decl = TypeDeclaration(
            id: id, kind: kind, qualifiedName: qn,
            location: location,
            genericParameters: genericParams,
            genericConstraints: constraints,
            inheritanceClauseRawNames: inherited,
            nestedTypeIds: [],
            memberSummary: summary
        )
        let index = declarations.count
        declarations.append(decl)
        nestedIdsStack[nestedIdsStack.count - 1].append(id)

        parentStack.append(name)
        scopeIndexStack.append(index)
        nestedIdsStack.append([])
    }

    private func leave() {
        let nested = nestedIdsStack.removeLast()
        let index = scopeIndexStack.removeLast()
        parentStack.removeLast()
        guard let i = index else { return }
        let old = declarations[i]
        declarations[i] = TypeDeclaration(
            id: old.id, kind: old.kind, qualifiedName: old.qualifiedName,
            location: old.location,
            genericParameters: old.genericParameters,
            genericConstraints: old.genericConstraints,
            inheritanceClauseRawNames: old.inheritanceClauseRawNames,
            nestedTypeIds: nested,
            memberSummary: old.memberSummary
        )
    }

    private static func summarize(_ members: MemberBlockSyntax) -> TypeDeclaration.MemberSummary {
        var stored = 0, computed = 0, methods = 0, inits = 0
        for item in members.members {
            let decl = item.decl
            if let v = decl.as(VariableDeclSyntax.self) {
                for binding in v.bindings {
                    if binding.accessorBlock != nil { computed += 1 } else { stored += 1 }
                }
            } else if decl.is(FunctionDeclSyntax.self) {
                methods += 1
            } else if decl.is(InitializerDeclSyntax.self) {
                inits += 1
            }
        }
        return .init(storedPropertyCount: stored,
                     computedPropertyCount: computed,
                     methodCount: methods,
                     initializerCount: inits)
    }

    private func makeLocation(of node: Syntax) -> SourceLocation {
        let pos = node.positionAfterSkippingLeadingTrivia
        let resolved = converter.location(for: pos)
        return SourceLocation(file: file.path, line: resolved.line, column: resolved.column)
    }
}

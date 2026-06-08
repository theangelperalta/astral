import Foundation
import SwiftSyntax

/// Walks a parsed source file once and produces unresolved `DependencyEdge`s
/// for every type reference made by any declaration in the file. Each edge
/// is tagged with the id of the lexically-enclosing declaration and, when
/// applicable, the surrounding `#if` condition.
public final class TypeUsageCollector: SyntaxVisitor {
    public internal(set) var edges: [DependencyEdge] = []

    let module: String
    let flattener: TypeSyntaxFlattener

    var ownerStack: [(id: TypeDeclaration.ID, kind: TypeKind, parents: [String])] = []
    var conditionStack: [String] = []

    public init(parsedFile: ParsedFile) {
        self.module = parsedFile.moduleName
        self.flattener = TypeSyntaxFlattener(file: parsedFile.url,
                                             converter: parsedFile.locationConverter)
        super.init(viewMode: .sourceAccurate)
    }

    public func collect(_ syntax: SourceFileSyntax) -> [DependencyEdge] {
        edges.removeAll(keepingCapacity: true)
        ownerStack.removeAll(keepingCapacity: true)
        conditionStack.removeAll(keepingCapacity: true)
        walk(syntax)
        return edges
    }

    // MARK: - Nominal scopes

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enterNominal(.struct, name: node.name.text, inheritance: node.inheritanceClause,
                     generics: node.genericParameterClause, whereClause: node.genericWhereClause)
        return .visitChildren
    }
    public override func visitPost(_ node: StructDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enterNominal(.class, name: node.name.text, inheritance: node.inheritanceClause,
                     generics: node.genericParameterClause, whereClause: node.genericWhereClause)
        return .visitChildren
    }
    public override func visitPost(_ node: ClassDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enterNominal(.enum, name: node.name.text, inheritance: node.inheritanceClause,
                     generics: node.genericParameterClause, whereClause: node.genericWhereClause)
        return .visitChildren
    }
    public override func visitPost(_ node: EnumDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enterNominal(.actor, name: node.name.text, inheritance: node.inheritanceClause,
                     generics: node.genericParameterClause, whereClause: node.genericWhereClause)
        return .visitChildren
    }
    public override func visitPost(_ node: ActorDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        enterNominal(.protocol, name: node.name.text, inheritance: node.inheritanceClause,
                     generics: nil, whereClause: node.genericWhereClause)
        return .visitChildren
    }
    public override func visitPost(_ node: ProtocolDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let parents = ownerParents()
        let nameText = node.extendedType.trimmedDescription
        let qn = QualifiedName(module: module, parents: parents, name: nameText)
        // Mirror DeclarationCollector — extension ids are file:line-tagged so
        // owner lookups in the resolver can find this declaration.
        let id = TypeDeclaration.makeExtensionId(qualifiedName: qn,
                                                 location: flattener.location(of: node))
        ownerStack.append((id: id, kind: .extension, parents: parents + [nameText]))
        for ref in flattener.references(in: node.extendedType, role: .extends) {
            appendEdge(ownerId: id, ref: ref, kind: .extends)
        }
        if let inh = node.inheritanceClause {
            collectInheritance(ownerId: id, ownerKind: .extension, clause: inh)
        }
        if let wc = node.genericWhereClause {
            collectWhere(ownerId: id, clause: wc)
        }
        return .visitChildren
    }
    public override func visitPost(_ node: ExtensionDeclSyntax) { ownerStack.removeLast() }

    public override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let parents = ownerParents()
        let qn = QualifiedName(module: module, parents: parents, name: node.name.text)
        let id = TypeDeclaration.makeId(qualifiedName: qn, kind: .typealias)
        ownerStack.append((id: id, kind: .typealias, parents: parents + [node.name.text]))
        for ref in flattener.references(in: node.initializer.value, role: .aliases) {
            appendEdge(ownerId: id, ref: ref, kind: .aliases)
        }
        return .visitChildren
    }
    public override func visitPost(_ node: TypeAliasDeclSyntax) { ownerStack.removeLast() }

    // MARK: - Members

    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        for binding in node.bindings {
            if let ann = binding.typeAnnotation?.type {
                for ref in flattener.references(in: ann, role: .propertyType) {
                    appendEdge(ownerId: owner.id, ref: ref, kind: .propertyType)
                }
            }
        }
        return .skipChildren
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        visitSignature(ownerId: owner.id,
                       parameters: node.signature.parameterClause.parameters,
                       returnType: node.signature.returnClause?.type,
                       generics: node.genericParameterClause,
                       whereClause: node.genericWhereClause)
        return .skipChildren
    }

    public override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        visitSignature(ownerId: owner.id,
                       parameters: node.signature.parameterClause.parameters,
                       returnType: nil,
                       generics: node.genericParameterClause,
                       whereClause: node.genericWhereClause)
        return .skipChildren
    }

    public override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        visitSignature(ownerId: owner.id,
                       parameters: node.parameterClause.parameters,
                       returnType: node.returnClause.type,
                       generics: node.genericParameterClause,
                       whereClause: node.genericWhereClause)
        return .skipChildren
    }

    public override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        if let inh = node.inheritanceClause {
            for inherited in inh.inheritedTypes {
                for ref in flattener.references(in: inherited.type, role: .genericConstraint) {
                    appendEdge(ownerId: owner.id, ref: ref, kind: .genericConstraint)
                }
            }
        }
        if let wc = node.genericWhereClause {
            collectWhere(ownerId: owner.id, clause: wc)
        }
        return .skipChildren
    }

    public override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let owner = ownerStack.last else { return .skipChildren }
        for element in node.elements {
            guard let params = element.parameterClause?.parameters else { continue }
            for param in params {
                for ref in flattener.references(in: param.type, role: .parameterType) {
                    appendEdge(ownerId: owner.id, ref: ref, kind: .parameterType)
                }
            }
        }
        return .skipChildren
    }

    // MARK: - Conditional compilation

    public override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        let condition = node.condition?.trimmedDescription ?? "#else"
        conditionStack.append(condition)
        return .visitChildren
    }
    public override func visitPost(_ node: IfConfigClauseSyntax) {
        _ = conditionStack.popLast()
    }
}

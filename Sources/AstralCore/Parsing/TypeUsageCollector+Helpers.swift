import Foundation
import SwiftSyntax

extension TypeUsageCollector {
    // MARK: - Scope helpers

    func ownerParents() -> [String] {
        ownerStack.last?.parents ?? []
    }

    func enterNominal(_ kind: TypeKind,
                      name: String,
                      inheritance: InheritanceClauseSyntax?,
                      generics: GenericParameterClauseSyntax?,
                      whereClause: GenericWhereClauseSyntax?) {
        let parents = ownerParents()
        let qn = QualifiedName(module: module, parents: parents, name: name)
        let id = TypeDeclaration.makeId(qualifiedName: qn, kind: kind)
        ownerStack.append((id: id, kind: kind, parents: parents + [name]))
        if let inh = inheritance {
            collectInheritance(ownerId: id, ownerKind: kind, clause: inh)
        }
        if let generics = generics {
            for param in generics.parameters {
                if let inherited = param.inheritedType {
                    for ref in flattener.references(in: inherited, role: .genericConstraint) {
                        appendEdge(ownerId: id, ref: ref, kind: .genericConstraint)
                    }
                }
            }
        }
        if let wc = whereClause {
            collectWhere(ownerId: id, clause: wc)
        }
    }

    // MARK: - Edge construction

    func appendEdge(ownerId: TypeDeclaration.ID,
                    ref: TypeReference,
                    kind: DependencyEdgeKind) {
        let edge = DependencyEdge(
            fromId: ownerId, to: ref, resolvedToIds: [],
            kind: kind, location: ref.location,
            condition: conditionStack.last
        )
        edges.append(edge)
    }

    func collectInheritance(ownerId: TypeDeclaration.ID,
                            ownerKind: TypeKind,
                            clause: InheritanceClauseSyntax) {
        for (index, inherited) in clause.inheritedTypes.enumerated() {
            let kind: DependencyEdgeKind = (ownerKind == .class && index == 0) ? .inherits : .conforms
            let role: TypeReference.Role = (kind == .inherits) ? .inherits : .conforms
            for ref in flattener.references(in: inherited.type, role: role) {
                appendEdge(ownerId: ownerId, ref: ref, kind: kind)
            }
        }
    }

    func collectWhere(ownerId: TypeDeclaration.ID, clause: GenericWhereClauseSyntax) {
        for requirement in clause.requirements {
            let types: [TypeSyntax]
            switch requirement.requirement {
            case .sameTypeRequirement(let r): types = [r.leftType, r.rightType]
            case .conformanceRequirement(let r): types = [r.leftType, r.rightType]
            case .layoutRequirement(let r): types = [r.type]
            }
            for t in types {
                for ref in flattener.references(in: t, role: .genericConstraint) {
                    appendEdge(ownerId: ownerId, ref: ref, kind: .genericConstraint)
                }
            }
        }
    }

    // MARK: - Signature helper (functions / initializers / subscripts)

    func visitSignature(ownerId: TypeDeclaration.ID,
                        parameters: FunctionParameterListSyntax,
                        returnType: TypeSyntax?,
                        generics: GenericParameterClauseSyntax?,
                        whereClause: GenericWhereClauseSyntax?) {
        for param in parameters {
            for ref in flattener.references(in: param.type, role: .parameterType) {
                appendEdge(ownerId: ownerId, ref: ref, kind: .parameterType)
            }
        }
        if let ret = returnType {
            for ref in flattener.references(in: ret, role: .returnType) {
                appendEdge(ownerId: ownerId, ref: ref, kind: .returnType)
            }
        }
        if let generics = generics {
            for param in generics.parameters {
                if let inherited = param.inheritedType {
                    for ref in flattener.references(in: inherited, role: .genericConstraint) {
                        appendEdge(ownerId: ownerId, ref: ref, kind: .genericConstraint)
                    }
                }
            }
        }
        if let wc = whereClause {
            collectWhere(ownerId: ownerId, clause: wc)
        }
    }
}

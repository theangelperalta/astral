import Foundation
import SwiftSyntax

/// Recursively reduces a `TypeSyntax` to a flat list of `TypeReference`s.
/// The flattener preserves the original textual form (`rawText`) and the
/// nested generic-argument tree for each reference.
struct TypeSyntaxFlattener {
    let file: URL
    let converter: SourceLocationConverter

    /// Flatten the top-level type into one or more references.
    /// - Tuple / composition / function types fan out into multiple refs;
    /// - Sugared wrappers (optional, IUO, array, `some`/`any`, attributed)
    ///   unwrap to a single inner ref;
    /// - Identifier / member types produce exactly one ref with their
    ///   generic arguments captured.
    func references(in type: TypeSyntax, role: TypeReference.Role) -> [TypeReference] {
        let trimmed = type.trimmedDescription

        if let id = type.as(IdentifierTypeSyntax.self) {
            return [makeIdentifierRef(name: id.name.text,
                                      raw: trimmed,
                                      generics: id.genericArgumentClause,
                                      location: location(of: type),
                                      role: role)]
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return [makeMemberRef(member: member,
                                  raw: trimmed,
                                  location: location(of: type),
                                  role: role)]
        }
        if let opt = type.as(OptionalTypeSyntax.self) {
            return references(in: opt.wrappedType, role: role)
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return references(in: iuo.wrappedType, role: role)
        }
        if let arr = type.as(ArrayTypeSyntax.self) {
            return references(in: arr.element, role: role)
        }
        if let dict = type.as(DictionaryTypeSyntax.self) {
            return references(in: dict.key, role: role) + references(in: dict.value, role: role)
        }
        if let attr = type.as(AttributedTypeSyntax.self) {
            return references(in: attr.baseType, role: role)
        }
        if let soa = type.as(SomeOrAnyTypeSyntax.self) {
            return references(in: soa.constraint, role: role)
        }
        if let fn = type.as(FunctionTypeSyntax.self) {
            var refs: [TypeReference] = []
            for param in fn.parameters {
                refs.append(contentsOf: references(in: param.type, role: role))
            }
            refs.append(contentsOf: references(in: fn.returnClause.type, role: role))
            return refs
        }
        if let tup = type.as(TupleTypeSyntax.self) {
            var refs: [TypeReference] = []
            for element in tup.elements {
                refs.append(contentsOf: references(in: element.type, role: role))
            }
            return refs
        }
        if let comp = type.as(CompositionTypeSyntax.self) {
            var refs: [TypeReference] = []
            for element in comp.elements {
                refs.append(contentsOf: references(in: element.type, role: role))
            }
            return refs
        }
        if let meta = type.as(MetatypeTypeSyntax.self) {
            return references(in: meta.baseType, role: role)
        }
        if let pack = type.as(PackExpansionTypeSyntax.self) {
            return references(in: pack.repetitionPattern, role: role)
        }
        if let pack = type.as(PackElementTypeSyntax.self) {
            return references(in: pack.pack, role: role)
        }
        return []
    }

    private func makeIdentifierRef(name: String,
                                   raw: String,
                                   generics: GenericArgumentClauseSyntax?,
                                   location: SourceLocation,
                                   role: TypeReference.Role) -> TypeReference {
        let genericRefs: [TypeReference] = (generics?.arguments ?? []).flatMap {
            references(in: $0.argument, role: role)
        }
        let candidates = [QualifiedName(module: nil, parents: [], name: name)]
        return TypeReference(rawText: raw,
                             candidateQualifiedNames: candidates,
                             genericArguments: genericRefs,
                             location: location,
                             role: role)
    }

    private func makeMemberRef(member: MemberTypeSyntax,
                               raw: String,
                               location: SourceLocation,
                               role: TypeReference.Role) -> TypeReference {
        // Collect dotted chain: base...name. The base may itself be member/identifier.
        let chain = memberChain(member: member)
        let genericRefs: [TypeReference] = (member.genericArgumentClause?.arguments ?? []).flatMap {
            references(in: $0.argument, role: role)
        }
        // Build qualified-name candidates:
        // 1) full dotted as written (treat first part as module);
        // 2) just the leaf name (unqualified fallback).
        var candidates: [QualifiedName] = []
        if chain.count > 1 {
            let module = chain.first
            let middle = Array(chain.dropFirst().dropLast())
            let leaf = chain.last ?? ""
            candidates.append(QualifiedName(module: module, parents: middle, name: leaf))
            candidates.append(QualifiedName(module: nil, parents: Array(chain.dropLast()), name: leaf))
        }
        candidates.append(QualifiedName(module: nil, parents: [], name: chain.last ?? ""))
        return TypeReference(rawText: raw,
                             candidateQualifiedNames: candidates,
                             genericArguments: genericRefs,
                             location: location,
                             role: role)
    }

    private func memberChain(member: MemberTypeSyntax) -> [String] {
        var parts: [String] = [member.name.text]
        var base: TypeSyntax = member.baseType
        while true {
            if let m = base.as(MemberTypeSyntax.self) {
                parts.insert(m.name.text, at: 0)
                base = m.baseType
            } else if let id = base.as(IdentifierTypeSyntax.self) {
                parts.insert(id.name.text, at: 0)
                break
            } else {
                break
            }
        }
        return parts
    }

    func location(of node: some SyntaxProtocol) -> SourceLocation {
        let pos = node.positionAfterSkippingLeadingTrivia
        let resolved = converter.location(for: pos)
        return SourceLocation(file: file.path, line: resolved.line, column: resolved.column)
    }
}

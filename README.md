# Astral

A SwiftSyntax-based dependency graph extractor for Swift codebases. Astral parses
Swift source files, collects type declarations and the references between them, and
exports a typed dependency graph to JSON, Graphviz DOT, and Mermaid.

It performs purely static, syntactic analysis — no compilation or build required.

## Features

- **Declaration discovery** — finds `protocol`, `class`, `struct`, `enum`, `actor`,
  `typealias`, and `extension` declarations, including nested types.
- **Typed edges** — captures how types relate to one another:
  `inherits`, `conforms`, `propertyType`, `parameterType`, `returnType`,
  `genericConstraint`, `extends`, `nests`, and `aliases`.
- **Module-aware resolution** — infers module names from directory layout (or via
  explicit `--module-roots`) and resolves references using per-file imports.
- **Multiple output formats** — JSON, DOT, and Mermaid.
- **Conditional compilation** — preserves the `#if` condition under which an edge
  applies.
- **Configurable scope** — exclude paths with glob patterns and optionally include
  references to known stdlib/Foundation types.

## Requirements

- macOS 13 or later
- Swift 5.10+ toolchain

## Building

```sh
swift build
```

This produces the `astral` executable. To run directly through SwiftPM:

```sh
swift run astral <subcommand> [options]
```

## Usage

Astral exposes three subcommands. `graph` is the default.

### `graph` — build and export a dependency graph

```sh
swift run astral graph \
  --input ./Sources \
  --output-dir ./astral-out \
  --format json dot mermaid
```

Options:

| Option | Description | Default |
| --- | --- | --- |
| `--input` | One or more input directories (recursive). **Required.** | — |
| `--output-dir` | Directory to write outputs. | `./astral-out` |
| `--format` | Output formats: `json`, `dot`, `mermaid`. | all three |
| `--module-roots` | Override module roots (each path becomes one module). | inferred |
| `--exclude` | Glob patterns to exclude. | none |
| `--include-stdlib-refs` | Emit edges to known stdlib/Foundation types. | off |
| `--deterministic` | Omit the generation timestamp for byte-reproducible output (CI-friendly). | off |
| `--quiet` | Suppress the summary written to stderr. | off |
| `--verbose` | Verbose output. | off |

Outputs are written as `graph.json`, `graph.dot`, and `graph.mmd` in the output
directory.

### `list-decls` — print discovered declarations

```sh
swift run astral list-decls --input ./Sources
```

Prints one line per declaration as `kind`, qualified name, and `file:line`.

### `version`

```sh
swift run astral version
```

## Output

The JSON graph contains:

- `nodes` — discovered type declarations keyed by id.
- `edges` — resolved dependency edges, each with a kind, source location, the
  resolved target id(s), and an optional `#if` condition.
- `unresolvedReferences` — references that could not be resolved to a known
  declaration.
- `metadata` — Astral version, generation timestamp, input roots, and module names.

The DOT and Mermaid outputs render the same graph for visualization (e.g. with
Graphviz or any Mermaid renderer).

## Project structure

```
Sources/
  Astral/        # CLI (ArgumentParser) — graph, list-decls, version subcommands
  AstralCore/    # Library (AstralCore)
    Discovery/   # File discovery, module layout, glob matching
    Parsing/     # SwiftSyntax parsing, declaration & type-usage collection
    Resolution/  # Symbol table, reference resolution, known external types
    Models/      # Graph, declarations, references, edges, locations
    Export/      # JSON, DOT, and Mermaid exporters
    Pipeline.swift
Tests/
  AstralCoreTests/   # Unit + end-to-end tests with fixtures
```

The pipeline is exposed as the `AstralCore` library and is fully usable
independently of the CLI.

## Architecture

`Pipeline.run(_:)` composes the stages end to end:

1. **Discover** source files under the input roots (applying excludes).
2. **Parse** each file with SwiftParser and assign it a module. Files are parsed
   in parallel (parsing is the dominant cost), with results reassembled in source
   order so output is unaffected.
3. **Collect** type declarations and type-usage edges from each file's syntax tree.
4. **Resolve** references against a symbol table using per-file imports.
5. **Assemble** the `DependencyGraph`, which can then be exported.

## Limitations

Astral performs purely **syntactic, name-based** analysis — it never invokes the
Swift type checker or builds the code. This keeps it fast and build-free, but means
the graph is an *approximation*. Be aware of the following:

- **No type inference.** Only types that are spelled out in the source become edges.
  Inferred types (`let x = makeThing()`, closures, operator results, etc.) contribute
  nothing, so the graph systematically *under-counts* real dependencies.
- **Ambiguous resolution.** Resolution is lexical. A bare reference like `Foo` that
  matches several declarations across modules (after the same-module and import tiers
  fail) resolves to *all* candidates. Precision therefore degrades on large codebases
  with repeated simple names. Unresolvable references are reported in
  `unresolvedReferences` rather than dropped.
- **Hardcoded standard-library list.** External types are recognized via a fixed
  allowlist (`KnownExternalTypes`). Stdlib/Foundation/third-party types not on that
  list surface as unresolved references. Use `--include-stdlib-refs` to keep known
  ones as edges.
- **No macro or conditional-compilation expansion.** Macros are not expanded. Code in
  every `#if` branch is analyzed (with the branch condition recorded on each edge);
  Astral does not pick a single active configuration.
- **Module inference is heuristic.** Module names are derived from directory layout
  unless you pass `--module-roots`; they won't necessarily match your actual SwiftPM /
  Xcode target boundaries.

In short: Astral is best for fast, approximate architecture overviews and visual
exploration — not for exhaustive or guaranteed-correct dependency facts.

## Dependencies

- [swift-syntax](https://github.com/swiftlang/swift-syntax) — parsing.
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI.

## Testing

```sh
swift test
```

Tests cover file discovery, parsing, declaration and type-usage collection,
resolution, export, model round-tripping, and end-to-end runs against the fixtures
under `Tests/AstralCoreTests/Fixtures`.

## License

Released under the [MIT License](LICENSE). © 2026 Angel Peralta.

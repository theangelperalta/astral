import Foundation

/// Applies `transform` to every element across multiple threads while
/// preserving input order in the result. If any invocation throws, the first
/// error encountered (by completion) is rethrown and the remaining results are
/// discarded.
///
/// Order preservation matters here: downstream resolution and node indexing
/// rely on "first occurrence wins, in source order", so parallelism must not
/// be observable in the output.
func parallelMap<Element, Result>(
    _ elements: [Element],
    _ transform: (Element) throws -> Result
) throws -> [Result] {
    let count = elements.count
    // Avoid the dispatch/allocation overhead when there's nothing to parallelize.
    guard count > 1 else { return try elements.map(transform) }

    var results = [Result?](repeating: nil, count: count)
    let errorLock = NSLock()
    var caught: Error?

    results.withUnsafeMutableBufferPointer { buffer in
        DispatchQueue.concurrentPerform(iterations: count) { index in
            // Stop doing work once another iteration has failed.
            errorLock.lock()
            let alreadyFailed = caught != nil
            errorLock.unlock()
            if alreadyFailed { return }

            do {
                buffer[index] = try transform(elements[index])
            } catch {
                errorLock.lock()
                if caught == nil { caught = error }
                errorLock.unlock()
            }
        }
    }

    if let caught { throw caught }
    return results.map { $0! }
}

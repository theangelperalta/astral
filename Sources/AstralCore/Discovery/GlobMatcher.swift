import Foundation

/// Minimal glob matcher used by FileDiscoverer.
/// Supports:
///   `*`  — any run of non-separator characters
///   `**` — any number of path segments (including zero)
///   `?`  — any single non-separator character
enum GlobMatcher {
    static func matchesAny(path: String, patterns: [String]) -> Bool {
        for p in patterns where matches(path: path, pattern: p) {
            return true
        }
        return false
    }

    static func matches(path: String, pattern: String) -> Bool {
        let regex = "^" + globToRegex(pattern) + "$"
        return path.range(of: regex, options: .regularExpression) != nil
    }

    private static func globToRegex(_ pattern: String) -> String {
        var result = ""
        let chars = Array(pattern)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "*":
                if i + 1 < chars.count, chars[i + 1] == "*" {
                    // `**` — match any number of path segments
                    // Consume optional trailing slash so `foo/**` matches `foo` and `foo/x`.
                    if i + 2 < chars.count, chars[i + 2] == "/" {
                        result += "(?:.*/)?"
                        i += 3
                    } else {
                        result += ".*"
                        i += 2
                    }
                } else {
                    result += "[^/]*"
                    i += 1
                }
            case "?":
                result += "[^/]"
                i += 1
            case ".", "+", "(", ")", "|", "^", "$", "{", "}", "[", "]", "\\":
                result += "\\\(c)"
                i += 1
            default:
                result.append(c)
                i += 1
            }
        }
        return result
    }
}

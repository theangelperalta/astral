import Foundation

protocol Logger {
    func log(_ message: String)
}

#if os(macOS)
struct MacLogger: Logger {
    func log(_ message: String) {}
}
#else
struct LinuxLogger: Logger {
    func log(_ message: String) {}
}
#endif

class Service {
    #if DEBUG
    let logger: Logger = {
        #if os(macOS)
        return MacLogger()
        #else
        return LinuxLogger()
        #endif
    }()
    #endif
}

import Foundation

/// Hard-coded allowlist of simple names from the Swift standard library and
/// Foundation that Astral treats as known external types and therefore
/// excludes from `DependencyGraph.unresolvedReferences` by default.
public enum KnownExternalTypes {
    public static let names: Set<String> = [
        // Primitives
        "String", "StaticString", "Substring",
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Double", "Float", "Float32", "Float64", "Bool",
        "Character", "Unicode",
        // Collections / sugar
        "Array", "Dictionary", "Set", "Optional", "Result",
        "Range", "ClosedRange", "PartialRangeFrom", "PartialRangeUpTo", "PartialRangeThrough",
        "Slice", "ArraySlice", "ContiguousArray",
        "Sequence", "Collection", "BidirectionalCollection", "RandomAccessCollection",
        "IteratorProtocol", "LazySequenceProtocol",
        // Protocols
        "Hashable", "Equatable", "Comparable", "Identifiable",
        "Codable", "Encodable", "Decodable",
        "Sendable", "AnyHashable", "CustomStringConvertible",
        "CustomDebugStringConvertible", "RawRepresentable",
        "Error", "LocalizedError", "CaseIterable", "OptionSet",
        "ExpressibleByIntegerLiteral", "ExpressibleByStringLiteral",
        "ExpressibleByArrayLiteral", "ExpressibleByDictionaryLiteral",
        // Codable / serialization
        "Encoder", "Decoder", "CodingKey", "CodingUserInfoKey",
        "KeyedEncodingContainer", "KeyedDecodingContainer",
        "UnkeyedEncodingContainer", "UnkeyedDecodingContainer",
        "SingleValueEncodingContainer", "SingleValueDecodingContainer",
        "JSONEncoder", "JSONDecoder", "PropertyListEncoder", "PropertyListDecoder",
        // Misc stdlib
        "Any", "AnyObject", "Void", "Never", "Self",
        // Foundation common
        "URL", "URLRequest", "URLSession", "URLResponse", "URLComponents",
        "URLQueryItem", "URLSessionTask", "URLSessionDataTask",
        "URLSessionDownloadTask", "URLSessionUploadTask", "URLSessionConfiguration",
        "HTTPURLResponse", "HTTPCookie", "HTTPCookieStorage",
        "Data", "Date", "DateComponents", "DateFormatter", "DateInterval",
        "ISO8601DateFormatter", "NumberFormatter",
        "UUID", "Decimal", "IndexPath", "IndexSet", "NSNumber", "NSString",
        "NSObject", "NSError", "NSNull", "NSCoder", "NSCoding", "NSSecureCoding",
        "NSDictionary", "NSArray", "NSSet", "NSMutableDictionary",
        "NSMutableArray", "NSMutableSet", "NSData", "NSDate", "NSValue",
        "Bundle", "FileManager", "FileHandle", "Process", "ProcessInfo",
        "Notification", "NotificationCenter", "Operation", "OperationQueue",
        "TimeInterval", "TimeZone", "Calendar", "Locale", "Measurement",
        "Progress", "RunLoop", "Timer", "Thread", "DispatchQueue",
        "DispatchGroup", "DispatchSemaphore", "DispatchTime", "DispatchSource",
        "DispatchSourceTimer", "DispatchData", "DispatchWorkItem",
        // Combine
        "Publisher", "Subscriber", "Subscription", "Cancellable", "AnyCancellable",
        "AnyPublisher", "PassthroughSubject", "CurrentValueSubject", "Just",
        "Future", "Empty", "Fail", "Published", "ObservableObject",
        // SwiftUI
        "View", "Text", "Image", "Button", "Color", "Font", "Spacer",
        "VStack", "HStack", "ZStack", "List", "ScrollView", "NavigationView",
        "NavigationStack", "NavigationLink", "Group", "ForEach", "EnvironmentObject",
        "Environment", "Binding", "State", "StateObject", "ObservedObject",
        "PreviewProvider", "EmptyView", "AnyView", "ViewBuilder", "ViewModifier",
        "Modifier", "EdgeInsets", "Alignment", "Axis", "Angle",
        // CoreGraphics
        "CGFloat", "CGSize", "CGRect", "CGPoint", "CGVector", "CGAffineTransform",
        "CGColor", "CGImage", "CGPath", "CGContext",
        // QuartzCore / CoreAnimation
        "CALayer", "CAAnimation", "CABasicAnimation", "CAKeyframeAnimation",
        "CAMediaTimingFunction", "CATransform3D", "CADisplayLink",
        // UIKit
        "UIView", "UIViewController", "UIWindow", "UIApplication", "UIScreen",
        "UIColor", "UIImage", "UIFont", "UIButton", "UILabel", "UITableView",
        "UITableViewCell", "UICollectionView", "UICollectionViewCell",
        "UIScrollView", "UIStackView", "UIGestureRecognizer", "UITapGestureRecognizer",
        "UIPanGestureRecognizer", "UINavigationController", "UITabBarController",
        "UIEdgeInsets", "UIDevice", "UIResponder", "UIControl", "UIEvent",
        "UITouch", "UIStoryboard", "UINib", "UIAlertController", "UIAlertAction",
        "UIBezierPath", "UIActivityIndicatorView", "UIRefreshControl",
        "UIBarButtonItem", "UINavigationBar", "UITabBar",
        // AVFoundation
        "AVPlayer", "AVQueuePlayer", "AVPlayerItem", "AVPlayerLayer",
        "AVPlayerViewController", "AVAsset", "AVURLAsset", "AVAssetTrack",
        "AVMediaSelectionGroup", "AVMediaSelectionOption", "AVMetadataItem",
        "AVAudioSession", "AVAudioPlayer", "AVCaptureSession", "AVCaptureDevice",
        "AVCaptureOutput", "AVCaptureInput",
        "AVPlayerItemAccessLogEvent", "AVPlayerItemErrorLogEvent",
        "AVPlayerItemStatus", "AVPlayerStatus", "AVPlayerTimeControlStatus",
        "CMTime", "CMTimeRange", "CMTimebase", "CMSampleBuffer", "CMFormatDescription",
        // MediaPlayer
        "MPNowPlayingInfoCenter", "MPRemoteCommandCenter", "MPRemoteCommand",
        "MPRemoteCommandHandlerStatus", "MPRemoteCommandEvent",
        "MPSkipIntervalCommandEvent", "MPChangePlaybackPositionCommandEvent",
        "MPMediaItem", "MPMediaItemArtwork",
        // os.log / Logger
        "Logger", "OSLog", "OSLogType", "OSSignposter",
    ]

    public static func isKnown(_ simpleName: String) -> Bool {
        names.contains(simpleName)
    }
}

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetTimelineReloader {
    static func reloadAll() {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
protocol WidgetTimelineReloading {
    func reloadAllTimelines()
}

@MainActor
struct NoopWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {}
}

#if canImport(WidgetKit)
@MainActor
struct LiveWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif

@MainActor
final class CapturingWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadCount = 0

    func reloadAllTimelines() {
        reloadCount += 1
    }
}

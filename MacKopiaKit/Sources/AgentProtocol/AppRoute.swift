import Foundation

/// Fixed window destinations the background service may ask the app to show.
/// The value carries no data, so an unauthenticated sender can at most switch the visible section.
public enum AppRoute: String, CaseIterable, Hashable, Sendable {
    case overview, plans, destinations, restore, activity

    public static let launchArgument = "-MacKopiaRoute"

    /// Distributed notification the running app observes; derived from the signed app identity.
    public static func notificationName(for identity: AgentServiceIdentity) -> Notification.Name {
        Notification.Name(identity.appBundleID + ".route")
    }

    public var launchArguments: [String] { [Self.launchArgument, rawValue] }

    /// Accepts only `-MacKopiaRoute <known route>`; anything else is ignored.
    public init?(arguments: [String]) {
        guard let index = arguments.firstIndex(of: Self.launchArgument), arguments.indices.contains(index + 1),
            let route = AppRoute(rawValue: arguments[index + 1])
        else { return nil }
        self = route
    }

    /// Accepts only an exact known route string as notification object.
    public init?(notificationObject: Any?) {
        guard let value = notificationObject as? String, value.utf8.count <= 32, let route = AppRoute(rawValue: value)
        else { return nil }
        self = route
    }
}

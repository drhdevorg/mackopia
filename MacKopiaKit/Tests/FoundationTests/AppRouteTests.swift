import AgentProtocol
import Foundation
import Testing

struct AppRouteTests {
    @Test func launchArgumentsRoundTripForEveryRoute() {
        for route in AppRoute.allCases {
            #expect(
                AppRoute(arguments: ["/Applications/MacKopia.app/Contents/MacOS/MacKopia"] + route.launchArguments)
                    == route)
        }
    }

    @Test func unknownOrIncompleteArgumentsAreIgnored() {
        #expect(AppRoute(arguments: []) == nil)
        #expect(AppRoute(arguments: [AppRoute.launchArgument]) == nil)
        #expect(AppRoute(arguments: [AppRoute.launchArgument, "settings"]) == nil)
        #expect(AppRoute(arguments: [AppRoute.launchArgument, "Restore"]) == nil)
        #expect(AppRoute(arguments: ["-NSDocumentRevisionsDebugMode", "YES"]) == nil)
    }

    @Test func notificationObjectAcceptsOnlyKnownStrings() {
        #expect(AppRoute(notificationObject: "restore") == .restore)
        #expect(AppRoute(notificationObject: nil) == nil)
        #expect(AppRoute(notificationObject: 1) == nil)
        #expect(AppRoute(notificationObject: "restore\0") == nil)
        #expect(AppRoute(notificationObject: String(repeating: "a", count: 4096)) == nil)
    }

    @Test func notificationNameIsBoundToAppIdentity() throws {
        let identity = try AgentServiceIdentity(appBundleID: "com.example.MacKopia")
        #expect(AppRoute.notificationName(for: identity).rawValue == "com.example.MacKopia.route")
    }
}

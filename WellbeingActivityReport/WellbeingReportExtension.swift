import DeviceActivity
import SwiftUI

// MARK: - Extension Entry Point
// This file lives in the WellbeingActivityReport app extension target.
// In Xcode: File > New > Target > Device Activity Report Extension
// Set bundle ID to: com.personal.productivitytimer.WellbeingReport
// Add App Groups capability: group.com.personal.productivitytimer

@main
struct WellbeingReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityScene { context in
            TotalActivityView(context: context)
        }
    }
}

// MARK: - Report Context
extension DeviceActivityReport.Context {
    static let totalActivity = DeviceActivityReport.Context("TotalActivity")
}

import Foundation

extension TimeInterval {
    /// Formats as H:MM:SS  e.g. "1:04:09" or "0:03:22"
    var hhmmss: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    /// Formats as a readable string e.g. "1h 4m" or "23m"
    var shortFormatted: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    /// Formats overtime as "+HH:MM:SS"
    var overtimeFormatted: String {
        guard self > 0 else { return "On time" }
        return "+" + hhmmss
    }
}

extension Date {
    var shortTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }

    var shortDateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }
}

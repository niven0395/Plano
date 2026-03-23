import Foundation

struct TimeslotConfig: Hashable, Codable, Sendable {
    var isEnabled: Bool
    var durationMinutes: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var bufferMinutes: Int
    var rollingWindowDays: Int
    var timezone: String

    static let disabled = TimeslotConfig(
        isEnabled: false,
        durationMinutes: 60,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        bufferMinutes: 0,
        rollingWindowDays: 14,
        timezone: TimeZone.current.identifier
    )

    static let allowedDurations = [15, 30, 45, 60, 90, 120]
    static let allowedBuffers = [0, 5, 10, 15, 30]

    func generatedSlots(for date: Date, existingBookings: [VendorTimeslotBookingRecord]) -> [TimeslotOption] {
        guard isEnabled else { return [] }

        let calendar = Calendar.current
        let dayStartMinutes = startHour * 60 + startMinute
        let dayEndMinutes = endHour * 60 + endMinute
        let step = durationMinutes + bufferMinutes

        guard step > 0, dayEndMinutes > dayStartMinutes else { return [] }

        let bookedSlots: [String: String] = existingBookings
            .filter { booking in
                guard let bookingDate = booking.date else { return false }
                return calendar.isDate(bookingDate, inSameDayAs: date)
            }
            .reduce(into: [:]) { result, booking in
                let key = String(booking.startTime.prefix(5))
                result[key] = booking.status
            }

        var slots: [TimeslotOption] = []
        var currentMinute = dayStartMinutes

        while currentMinute + durationMinutes <= dayEndMinutes {
            let slotStartHour = currentMinute / 60
            let slotStartMinute = currentMinute % 60
            let slotEndTotal = currentMinute + durationMinutes
            let slotEndHour = slotEndTotal / 60
            let slotEndMin = slotEndTotal % 60

            let timeKey = String(format: "%02d:%02d", slotStartHour, slotStartMinute)

            let status: TimeslotStatus
            if let bookedStatus = bookedSlots[timeKey] {
                status = TimeslotStatus(rawValue: bookedStatus) ?? .available
            } else {
                status = .available
            }

            slots.append(TimeslotOption(
                id: timeKey,
                startTime: DateComponents(hour: slotStartHour, minute: slotStartMinute),
                endTime: DateComponents(hour: slotEndHour, minute: slotEndMin),
                status: status
            ))

            currentMinute += step
        }

        return slots
    }

    var slotCount: Int {
        guard isEnabled else { return 0 }
        let dayStartMinutes = startHour * 60 + startMinute
        let dayEndMinutes = endHour * 60 + endMinute
        let step = durationMinutes + bufferMinutes
        guard step > 0, dayEndMinutes > dayStartMinutes else { return 0 }

        var count = 0
        var current = dayStartMinutes
        while current + durationMinutes <= dayEndMinutes {
            count += 1
            current += step
        }
        return count
    }

    var dailyStartTimeLabel: String {
        Self.formatTime(hour: startHour, minute: startMinute)
    }

    var dailyEndTimeLabel: String {
        Self.formatTime(hour: endHour, minute: endMinute)
    }

    var durationLabel: String {
        if durationMinutes >= 60 {
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        }
        return "\(durationMinutes) min"
    }

    var bufferLabel: String {
        bufferMinutes == 0 ? "None" : "\(bufferMinutes) min"
    }

    var rollingWindowLabel: String {
        switch rollingWindowDays {
        case 7: "1 week"
        case 14: "2 weeks"
        case 21: "3 weeks"
        case 28...31: "1 month"
        case 56...62: "2 months"
        case 84...93: "3 months"
        default: "\(rollingWindowDays) days"
        }
    }

    var slotPreviewLabel: String {
        let count = slotCount
        guard count > 0 else { return "No slots configured" }

        let slots = generatedSlots(for: Date.now, existingBookings: [])
        let previewTimes = slots.prefix(3).map(\.startTimeLabel)
        let preview = previewTimes.joined(separator: ", ")

        if count > 3 {
            return "\(preview)... (\(count) slots)"
        }
        return "\(preview) (\(count) slots)"
    }

    private static func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

struct TimeslotOption: Identifiable, Hashable, Sendable {
    let id: String
    let startTime: DateComponents
    let endTime: DateComponents
    let status: TimeslotStatus

    var startTimeLabel: String {
        Self.formatComponents(startTime)
    }

    var endTimeLabel: String {
        Self.formatComponents(endTime)
    }

    var timeRangeLabel: String {
        "\(startTimeLabel) – \(endTimeLabel)"
    }

    var startTimeString: String {
        String(format: "%02d:%02d:00", startTime.hour ?? 0, startTime.minute ?? 0)
    }

    var endTimeString: String {
        String(format: "%02d:%02d:00", endTime.hour ?? 0, endTime.minute ?? 0)
    }

    private static func formatComponents(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

enum TimeslotStatus: String, Hashable, Sendable {
    case available
    case booked
    case blocked
    case hold
}

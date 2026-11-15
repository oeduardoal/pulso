import Foundation

/// Locale-aware formatting for every value shown in the UI.
enum Format {
    static func percent(_ fraction: Double, digits: Int = 0) -> String {
        fraction.formatted(.percent.precision(.fractionLength(digits)))
    }

    /// Bare number of percent points ("6.2"), for process lists with a "% CPU" header.
    static func points(_ fraction: Double) -> String {
        (fraction * 100).formatted(.number.precision(.fractionLength(1)))
    }

    /// RAM sizes use binary units, like Activity Monitor.
    static func memory(_ bytes: UInt64) -> String {
        byteCount(bytes, style: .memory)
    }

    /// Storage sizes use decimal units, like Finder.
    static func storage(_ bytes: UInt64) -> String {
        byteCount(bytes, style: .file)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        L("unit.perSecond", byteCount(UInt64(max(0, bytesPerSecond)), style: .file))
    }

    /// Three significant digits ("431 GB", "14.1 GB", "2.4 MB"). The format style API always
    /// shows two decimals for gigabytes, which is noisier than the design.
    private static func byteCount(_ bytes: UInt64, style: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = style
        formatter.isAdaptive = false
        formatter.allowsNonnumericFormatting = false
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB, .usePB]
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    static func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius.rounded(), unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// Compact temperature for the menu bar ("54°").
    static func degrees(_ celsius: Double) -> String {
        L("unit.degrees", Int(celsius.rounded()).formatted())
    }

    static func number(_ value: Double, digits: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    static func integer(_ value: Int) -> String {
        value.formatted()
    }

    static func rpm(_ value: Double) -> String {
        L("unit.rpm", Int(value.rounded()).formatted())
    }

    static func watts(_ value: Double) -> String {
        Measurement(value: value, unit: UnitPower.watts)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    static func milliseconds(_ value: Double) -> String {
        Measurement(value: value.rounded(), unit: UnitDuration.milliseconds)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "today at 1:05 PM", "yesterday at 9:12 AM" or a full date.
    static func relativeDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        formatter.formattingContext = .middleOfSentence
        return formatter.string(from: date)
    }
}

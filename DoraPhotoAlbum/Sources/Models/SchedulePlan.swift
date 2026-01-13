import Foundation

struct SchedulePlan: Codable, Equatable {
    var id: String
    var title: String
    
    var sleepEnabled: Bool
    var wakeEnabled: Bool
    
    /// Minutes since midnight, 0...1439
    var sleepMinutes: Int
    var wakeMinutes: Int
    
    /// 1=Monday ... 7=Sunday
    var sleepWeekdays: [Int]
    var wakeWeekdays: [Int]
    
    static func `default`(title: String = "计划") -> SchedulePlan {
        return SchedulePlan(
            id: UUID().uuidString,
            title: title,
            sleepEnabled: true,
            wakeEnabled: true,
            sleepMinutes: 22 * 60,
            wakeMinutes: 7 * 60,
            sleepWeekdays: Array(1...7),
            wakeWeekdays: Array(1...7)
        )
    }
}

enum SchedulePlanStore {
    static func load() -> [SchedulePlan] {
        let defaults = UserDefaults.standard
        
        if let data = defaults.data(forKey: AppConstants.Keys.kSchedulePlans) {
            if let decoded = try? JSONDecoder().decode([SchedulePlan].self, from: data) {
                return decoded
            }
        }
        
        // Migration from legacy single-schedule keys (v1)
        let legacyTouched =
            defaults.object(forKey: AppConstants.Keys.kSleepEnabled) != nil ||
            defaults.object(forKey: AppConstants.Keys.kWakeEnabled) != nil ||
            defaults.object(forKey: AppConstants.Keys.kSleepTime) != nil ||
            defaults.object(forKey: AppConstants.Keys.kWakeTime) != nil ||
            defaults.object(forKey: AppConstants.Keys.kSleepWeekdays) != nil ||
            defaults.object(forKey: AppConstants.Keys.kWakeWeekdays) != nil
        
        guard legacyTouched else { return [] }
        
        let sleepEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kSleepEnabled) != nil {
            sleepEnabled = defaults.bool(forKey: AppConstants.Keys.kSleepEnabled)
        } else {
            sleepEnabled = AppConstants.Defaults.sleepEnabled
        }
        
        let wakeEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kWakeEnabled) != nil {
            wakeEnabled = defaults.bool(forKey: AppConstants.Keys.kWakeEnabled)
        } else {
            wakeEnabled = AppConstants.Defaults.wakeEnabled
        }
        
        let sleepDate = (defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date) ?? AppConstants.Defaults.defaultSleepTime
        let wakeDate = (defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date) ?? AppConstants.Defaults.defaultWakeTime
        
        let sleepWeekdays = (defaults.array(forKey: AppConstants.Keys.kSleepWeekdays) as? [Int]) ?? Array(1...7)
        let wakeWeekdays = (defaults.array(forKey: AppConstants.Keys.kWakeWeekdays) as? [Int]) ?? Array(1...7)
        
        let plan = SchedulePlan(
            id: UUID().uuidString,
            title: "计划 1",
            sleepEnabled: sleepEnabled,
            wakeEnabled: wakeEnabled,
            sleepMinutes: minutesSinceMidnight(from: sleepDate),
            wakeMinutes: minutesSinceMidnight(from: wakeDate),
            sleepWeekdays: sleepWeekdays,
            wakeWeekdays: wakeWeekdays
        )
        // Note: don't auto-save here; UI/save path will persist.
        return [plan]
    }
    
    static func save(_ plans: [SchedulePlan]) {
        let defaults = UserDefaults.standard
        let data = try? JSONEncoder().encode(plans)
        defaults.set(data, forKey: AppConstants.Keys.kSchedulePlans)
        
        // Keep legacy enable keys in sync for other parts of the app.
        let anySleep = plans.contains { $0.sleepEnabled }
        let anyWake = plans.contains { $0.wakeEnabled }
        defaults.set(anySleep, forKey: AppConstants.Keys.kSleepEnabled)
        defaults.set(anyWake, forKey: AppConstants.Keys.kWakeEnabled)
        
        defaults.synchronize()
    }
    
    static func hasAnyEnabledPlan() -> Bool {
        let plans = load()
        return plans.contains { $0.sleepEnabled || $0.wakeEnabled }
    }
    
    static func minutesSinceMidnight(from date: Date) -> Int {
        let cal = Calendar.current
        let comp = cal.dateComponents([.hour, .minute], from: date)
        let h = comp.hour ?? 0
        let m = comp.minute ?? 0
        return max(0, min(1439, h * 60 + m))
    }
    
    static func dateForToday(fromMinutes minutes: Int) -> Date {
        let clamped = max(0, min(1439, minutes))
        let h = clamped / 60
        let m = clamped % 60
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: Date())
        comp.hour = h
        comp.minute = m
        comp.second = 0
        return cal.date(from: comp) ?? Date()
    }
    
    static func timeString(fromMinutes minutes: Int) -> String {
        let clamped = max(0, min(1439, minutes))
        let h = clamped / 60
        let m = clamped % 60
        return String(format: "%02d:%02d", h, m)
    }
    
    static func weekdaysShortString(_ weekdays: [Int]) -> String {
        let map: [Int: String] = [1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "日"]
        let uniq = Array(Set(weekdays)).sorted()
        if uniq.count == 7 { return "每天" }
        if uniq.isEmpty { return "不生效" }
        return uniq.compactMap { map[$0] }.joined()
    }
}


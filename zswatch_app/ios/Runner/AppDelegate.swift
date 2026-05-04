import EventKit
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let productivityChannelName = "dev.zswatch.app/productivity"
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: productivityChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleProductivityCall(call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleProductivityCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createAction":
      handleCreateAction(call, result: result)
    case "getDeviceMemoryMB":
      let bytes = ProcessInfo.processInfo.physicalMemory
      result(Int(bytes / (1024 * 1024)))
    case "getAvailableMemoryMB":
      // On iOS, use os_proc_available_memory (iOS 13.0+) for real-time free RAM.
      let availableMB: Int
      if #available(iOS 13.0, *) {
        availableMB = Int(os_proc_available_memory()) / (1024 * 1024)
      } else {
        // Fallback: conservative estimate of 40% of physical memory
        availableMB = Int(ProcessInfo.processInfo.physicalMemory * 40 / 100) / (1024 * 1024)
      }
      result(availableMB)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCreateAction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing action arguments.", details: nil))
      return
    }

    let actionType = (args["actionType"] as? String) ?? "task"
    let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let notes = (args["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let location = (args["location"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let scheduledAtMillis = (args["scheduledAtMillis"] as? NSNumber)?.doubleValue
    let endAtMillis = (args["endAtMillis"] as? NSNumber)?.doubleValue
    let reminderMinutes = (args["reminderMinutes"] as? NSNumber)?.intValue
    let durationSeconds = (args["durationSeconds"] as? NSNumber)?.intValue

    // Timer and alarm use Clock app URLs on iOS — no calendar permission needed.
    if actionType == "timer" {
      createTimerViaClockApp(durationSeconds: durationSeconds ?? 0, label: title, result: result)
      return
    }
    if actionType == "alarm" {
      createAlarmViaClockApp(scheduledAtMillis: scheduledAtMillis, label: title, result: result)
      return
    }

    guard !title.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "title is required", details: nil))
      return
    }

    switch actionType {
    case "calendar_event":
      createCalendarEvent(
        title: title,
        notes: notes,
        location: location,
        scheduledAtMillis: scheduledAtMillis,
        endAtMillis: endAtMillis,
        reminderMinutes: reminderMinutes,
        result: result
      )
    case "reminder", "task":
      createReminder(
        title: title,
        notes: notes,
        scheduledAtMillis: scheduledAtMillis,
        reminderMinutes: reminderMinutes,
        result: result
      )
    default:
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Unsupported action type: \(actionType)", details: nil))
    }
  }

  private func createTimerViaClockApp(durationSeconds: Int, label: String, result: @escaping FlutterResult) {
    guard durationSeconds > 0 else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "durationSeconds must be > 0", details: nil))
      return
    }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Notification permission not granted", details: nil))
        }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = label.isEmpty ? "Timer" : label
      content.body = "Your timer has finished!"
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: TimeInterval(durationSeconds),
        repeats: false
      )
      let identifier = "timer-\(UUID().uuidString)"
      let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
      center.add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "SCHEDULE_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result([
              "platformId": identifier,
              "targetType": "timer",
              "syncDisabled": false,
            ] as [String: Any?])
          }
        }
      }
    }
  }

  private func createAlarmViaClockApp(scheduledAtMillis: Double?, label: String, result: @escaping FlutterResult) {
    guard let scheduledAtMillis = scheduledAtMillis else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "scheduledAtMillis is required", details: nil))
      return
    }
    let fireDate = Date(timeIntervalSince1970: scheduledAtMillis / 1000.0)
    guard fireDate > Date() else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Alarm time must be in the future", details: nil))
      return
    }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Notification permission not granted", details: nil))
        }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = label.isEmpty ? "Alarm" : label
      content.body = "Your alarm is ringing!"
      content.sound = .default
      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: fireDate
      )
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let identifier = "alarm-\(UUID().uuidString)"
      let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
      center.add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "SCHEDULE_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result([
              "platformId": identifier,
              "targetType": "alarm",
              "syncDisabled": false,
            ] as [String: Any?])
          }
        }
      }
    }
  }

  private func createCalendarEvent(
    title: String,
    notes: String?,
    location: String?,
    scheduledAtMillis: Double?,
    endAtMillis: Double?,
    reminderMinutes: Int?,
    result: @escaping FlutterResult
  ) {
    guard let scheduledAtMillis else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "A start time is required for calendar events.", details: nil))
      return
    }

    requestEventAccess { [weak self] granted, error in
      guard let self else { return }

      if let error {
        DispatchQueue.main.async { result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil)) }
        return
      }

      guard granted else {
        DispatchQueue.main.async { result(FlutterError(code: "PERMISSION_DENIED", message: "Calendar access was denied.", details: nil)) }
        return
      }

      guard let calendar = self.eventStore.defaultCalendarForNewEvents else {
        DispatchQueue.main.async { result(FlutterError(code: "NO_CALENDAR", message: "No writable calendar was found.", details: nil)) }
        return
      }

      let startDate = Date(timeIntervalSince1970: scheduledAtMillis / 1000)
      let endDate = Date(
        timeIntervalSince1970: (endAtMillis ?? (scheduledAtMillis + 30 * 60 * 1000)) / 1000
      )

      let event = EKEvent(eventStore: self.eventStore)
      event.calendar = calendar
      event.title = title
      event.notes = notes
      event.location = location
      event.startDate = startDate
      event.endDate = endDate

      if let reminderMinutes {
        let alarmDate = startDate.addingTimeInterval(TimeInterval(-reminderMinutes * 60))
        event.addAlarm(EKAlarm(absoluteDate: alarmDate))
      }

      do {
        try self.eventStore.save(event, span: .thisEvent, commit: true)
        DispatchQueue.main.async {
          result([
            "platformId": event.calendarItemIdentifier,
            "targetType": "calendar_event",
          ])
        }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "CREATE_ACTION_FAILED", message: error.localizedDescription, details: nil)) }
      }
    }
  }

  private func createReminder(
    title: String,
    notes: String?,
    scheduledAtMillis: Double?,
    reminderMinutes: Int?,
    result: @escaping FlutterResult
  ) {
    requestReminderAccess { [weak self] granted, error in
      guard let self else { return }

      if let error {
        DispatchQueue.main.async { result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil)) }
        return
      }

      guard granted else {
        DispatchQueue.main.async { result(FlutterError(code: "PERMISSION_DENIED", message: "Reminder access was denied.", details: nil)) }
        return
      }

      guard let calendar = self.eventStore.defaultCalendarForNewReminders() else {
        DispatchQueue.main.async { result(FlutterError(code: "NO_CALENDAR", message: "No reminders list was found.", details: nil)) }
        return
      }

      let reminder = EKReminder(eventStore: self.eventStore)
      reminder.calendar = calendar
      reminder.title = title
      reminder.notes = notes

      if let scheduledAtMillis {
        let dueDate = Date(timeIntervalSince1970: scheduledAtMillis / 1000)
        reminder.dueDateComponents = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: dueDate
        )

        let offset = reminderMinutes ?? 0
        let alarmDate = dueDate.addingTimeInterval(TimeInterval(-offset * 60))
        reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
      }

      do {
        try self.eventStore.save(reminder, commit: true)
        DispatchQueue.main.async {
          result([
            "platformId": reminder.calendarItemIdentifier,
            "targetType": "reminder",
          ])
        }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "CREATE_ACTION_FAILED", message: error.localizedDescription, details: nil)) }
      }
    }
  }

  private func requestEventAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func requestReminderAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToReminders(completion: completion)
    } else {
      eventStore.requestAccess(to: .reminder, completion: completion)
    }
  }
}

import EventKit
import Flutter
import UIKit

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
    guard call.method == "createAction" else {
      result(FlutterMethodNotImplemented)
      return
    }

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
        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        return
      }

      guard granted else {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Calendar access was denied.", details: nil))
        return
      }

      guard let calendar = self.eventStore.defaultCalendarForNewEvents else {
        result(FlutterError(code: "NO_CALENDAR", message: "No writable calendar was found.", details: nil))
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
        result([
          "platformId": event.calendarItemIdentifier,
          "targetType": "calendar_event",
        ])
      } catch {
        result(FlutterError(code: "CREATE_ACTION_FAILED", message: error.localizedDescription, details: nil))
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
        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        return
      }

      guard granted else {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Reminder access was denied.", details: nil))
        return
      }

      guard let calendar = self.eventStore.defaultCalendarForNewReminders() else {
        result(FlutterError(code: "NO_CALENDAR", message: "No reminders list was found.", details: nil))
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
        result([
          "platformId": reminder.calendarItemIdentifier,
          "targetType": "reminder",
        ])
      } catch {
        result(FlutterError(code: "CREATE_ACTION_FAILED", message: error.localizedDescription, details: nil))
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

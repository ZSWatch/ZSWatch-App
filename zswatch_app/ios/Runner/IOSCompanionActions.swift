import EventKit
import EventKitUI
import Flutter
import Foundation
import UIKit
import UserNotifications

/// User-confirmed actions only. Journal confirmation precedes external mutation.
final class IOSCompanionActions: NSObject, EKEventViewDelegate {
  private let owner: IOSCompanionCoordinator
  private let store = EKEventStore()
  private let presenter: () -> UIViewController?
  private var eventViewer: EKEventViewController?
  private var inFlight = Set<String>() // Main-owned; two callers cannot create one action concurrently.
  init(owner: IOSCompanionCoordinator, presenter: @escaping () -> UIViewController?) {
    self.owner = owner; self.presenter = presenter; super.init()
  }
  func handle(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["jobId"] as? String, let index = CompanionRecordingFiles.integer(args["index"]),
          let operation = args["operation"] as? String, ["create", "dismiss", "undo", "open"].contains(operation) else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Confirmed voice action required", details: nil)); return
    }
    let key = "\(id).\(index)"
    guard inFlight.insert(key).inserted else { result(FlutterError(code: "BUSY", message: "Action already in progress", details: nil)); return }
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { self.inFlight.remove(key); result(value) } }
    owner.queue.async {
      do {
        guard let jobs = self.owner.voice?.jobs else { throw CompanionFailure.unavailable("Voice journal unavailable") }
        if operation == "dismiss" { try jobs.dismissAction(id, index: index); self.owner.journalChanged(); reply(nil); return }
        if operation == "open" {
          let detail = try jobs.detail(id)
          guard let states = detail["action_states"] as? [String: [String: Any]],
                let state = states[String(index)], state["state"] as? String == "created",
                let response = state["response"] as? [String: Any], response["targetType"] as? String == "calendar_event",
                let identifier = response["platformId"] as? String else {
            throw CompanionFailure.unavailable("Created calendar event required")
          }
          DispatchQueue.main.async { self.openEvent(identifier, key, reply) }
          return
        }
        let action: [String: Any]
        if operation == "undo" { action = try jobs.beginUndo(id, index: index) }
        else {
          guard let draft = args["draft"] as? [String: Any] else { throw CompanionFailure.invalid("Confirmed draft required") }
          action = try jobs.beginAction(id, index: index, draft: draft)
        }
        self.owner.journalChanged()
        DispatchQueue.main.async {
          if operation == "undo" { self.undo(id, index, key, action, reply) }
          else { self.create(id, index, key, action, reply) }
        }
      } catch { reply(FlutterError(code: "ACTION_FAILED", message: error.localizedDescription, details: nil)) }
    }
  }
  private func openEvent(_ identifier: String, _ key: String, _ reply: @escaping (Any?) -> Void) {
    authorize("calendar_event") { granted in
      guard granted else { reply(FlutterError(code: "PERMISSION_DENIED", message: "Calendar access is required to open this event", details: nil)); return }
      guard let event = self.store.calendarItem(withIdentifier: identifier) as? EKEvent,
            event.url == URL(string: "zswatch-action://" + key) else {
        reply(FlutterError(code: "EVENT_UNAVAILABLE", message: "The created event is no longer available in Calendar", details: nil)); return
      }
      guard UIApplication.shared.applicationState == .active, let presenter = self.presenter(),
            presenter.presentedViewController == nil else {
        reply(FlutterError(code: "UI_UNAVAILABLE", message: "Open this event while ZSWatch is in the foreground", details: nil)); return
      }
      let viewer = EKEventViewController(); viewer.event = event
      viewer.allowsEditing = false; viewer.allowsCalendarPreview = false; viewer.delegate = self
      viewer.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.closeEventViewer))
      self.eventViewer = viewer
      presenter.present(UINavigationController(rootViewController: viewer), animated: true)
      reply(nil)
    }
  }
  @objc private func closeEventViewer() { eventViewer?.dismiss(animated: true); eventViewer = nil }
  func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
    controller.dismiss(animated: true); eventViewer = nil
  }
  private func complete(_ id: String, _ index: Int, _ response: [String: Any], _ reply: @escaping (Any?) -> Void) {
    owner.queue.async {
      do { try self.owner.voice?.jobs.finishAction(id, index: index, response: response); self.owner.journalChanged(); reply(nil) }
      catch { reply(FlutterError(code: "ACTION_OUTCOME_UNKNOWN", message: "Creation may have completed. Recover the existing action before retrying.", details: nil)) }
    }
  }
  private func reject(_ id: String, _ index: Int, _ message: String, _ reply: @escaping (Any?) -> Void) {
    owner.queue.async {
      let detail = try? self.owner.voice?.jobs.detail(id)
      if ((detail?["action_states"] as? [String: [String: Any]])?[String(index)]?["effect_admitted"] as? Bool) == true { self.unknown(reply); return }
      try? self.owner.voice?.jobs.releaseAction(id, index: index); self.owner.journalChanged()
      reply(FlutterError(code: "ACTION_NOT_CREATED", message: message, details: nil))
    }
  }
  private func unknown(_ reply: (Any?) -> Void) {
    reply(FlutterError(code: "ACTION_OUTCOME_UNKNOWN", message: "The previous action may have completed. Check Calendar, Reminders or scheduled alerts before creating another.", details: nil))
  }
  private func admit(_ id: String, _ index: Int, _ reply: @escaping (Any?) -> Void, _ work: @escaping () -> Void) {
    owner.queue.async {
      do { try self.owner.voice?.jobs.admitAction(id, index: index); self.owner.journalChanged(); DispatchQueue.main.async(execute: work) }
      catch { reply(FlutterError(code: "ACTION_FAILED", message: "Could not persist action admission", details: nil)) }
    }
  }
  private func authorize(_ type: String, done: @escaping (Bool) -> Void) {
    let completion: (Bool, Error?) -> Void = { granted, _ in DispatchQueue.main.async { done(granted) } }
    if type == "calendar_event" {
      if #available(iOS 17.0, *) { store.requestFullAccessToEvents(completion: completion) }
      else { store.requestAccess(to: .event, completion: completion) }
    } else {
      if #available(iOS 17.0, *) { store.requestFullAccessToReminders(completion: completion) }
      else { store.requestAccess(to: .reminder, completion: completion) }
    }
  }
  private func create(_ id: String, _ index: Int, _ key: String, _ action: [String: Any], _ reply: @escaping (Any?) -> Void) {
    guard let draft = action["draft"] as? [String: Any], let type = draft["actionType"] as? String, let title = draft["title"] as? String else { unknown(reply); return }
    if ["timer", "alarm"].contains(type) { notification(id, index, key, action, draft, reply); return }
    authorize(type) { granted in
      guard granted else { self.reject(id, index, "Calendar or Reminders permission denied", reply); return }
      let marker = URL(string: "zswatch-action://" + key)!
      if type == "calendar_event" {
        guard let ms = CompanionRecordingFiles.integer(draft["scheduledAtMillis"]), ms < 4102444800000 else { self.reject(id, index, "Valid event time required", reply); return }
        let start = Date(timeIntervalSince1970: Double(ms) / 1000)
        let end = Date(timeIntervalSince1970: Double(CompanionRecordingFiles.integer(draft["endAtMillis"]) ?? ms + 1800000) / 1000)
        guard end > start, end.timeIntervalSince(start) <= 366 * 86400 else { self.reject(id, index, "Valid event end required", reply); return }
        let predicate = self.store.predicateForEvents(withStart: start.addingTimeInterval(-86400), end: start.addingTimeInterval(86400), calendars: nil)
        if let existing = self.store.events(matching: predicate).first(where: { $0.url == marker }) {
          self.complete(id, index, ["platformId": existing.calendarItemIdentifier, "targetType": "calendar_event"], reply); return
        }
        guard action["effect_admitted"] as? Bool != true else { self.unknown(reply); return }
        guard let calendar = self.store.defaultCalendarForNewEvents, calendar.allowsContentModifications else { self.reject(id, index, "No writable calendar", reply); return }
        let event = EKEvent(eventStore: self.store); event.calendar = calendar; event.title = title; event.notes = draft["notes"] as? String
        event.location = draft["location"] as? String; event.startDate = start; event.endDate = end; event.url = marker
        if let minutes = CompanionRecordingFiles.integer(draft["reminderMinutes"]) { event.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60)) }
        self.admit(id, index, reply) {
          do { try self.store.save(event, span: .thisEvent, commit: true); self.complete(id, index, ["platformId": event.calendarItemIdentifier, "targetType": "calendar_event"], reply) }
          catch { self.unknown(reply) }
        }
      } else {
        let predicate = self.store.predicateForReminders(in: nil)
        self.store.fetchReminders(matching: predicate) { reminders in
          DispatchQueue.main.async {
            guard let reminders else { self.unknown(reply); return }
            if let existing = reminders.first(where: { $0.url == marker }) { self.complete(id, index, ["platformId": existing.calendarItemIdentifier, "targetType": "reminder"], reply); return }
            guard action["effect_admitted"] as? Bool != true else { self.unknown(reply); return }
            guard let calendar = self.store.defaultCalendarForNewReminders(), calendar.allowsContentModifications else { self.reject(id, index, "No writable reminders list", reply); return }
            let reminder = EKReminder(eventStore: self.store); reminder.calendar = calendar; reminder.title = title; reminder.notes = draft["notes"] as? String; reminder.url = marker
            if let ms = CompanionRecordingFiles.integer(draft["scheduledAtMillis"]) {
              let date = Date(timeIntervalSince1970: Double(ms) / 1000)
              reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
              reminder.addAlarm(EKAlarm(absoluteDate: date.addingTimeInterval(-Double(CompanionRecordingFiles.integer(draft["reminderMinutes"]) ?? 0) * 60)))
            }
            self.admit(id, index, reply) {
              do { try self.store.save(reminder, commit: true); self.complete(id, index, ["platformId": reminder.calendarItemIdentifier, "targetType": "reminder"], reply) }
              catch { self.unknown(reply) }
            }
          }
        }
      }
    }
  }
  private func notification(_ id: String, _ index: Int, _ key: String, _ action: [String: Any], _ draft: [String: Any], _ reply: @escaping (Any?) -> Void) {
    let identifier = "zswatch.voice.alert." + key
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { self.reject(id, index, "Notification permission denied", reply); return }
      center.getPendingNotificationRequests { pending in
        center.getDeliveredNotifications { delivered in
          if pending.contains(where: { $0.identifier == identifier }) || delivered.contains(where: { $0.request.identifier == identifier }) {
            self.complete(id, index, ["platformId": identifier, "targetType": draft["actionType"]!], reply); return
          }
          guard action["effect_admitted"] as? Bool != true else { self.unknown(reply); return }
          let ms = draft["actionType"] as? String == "timer" ? CompanionRecordingFiles.integer(action["fire_utc_ms"]) : CompanionRecordingFiles.integer(draft["scheduledAtMillis"])
          guard let ms, ms > CompanionJournal.now else { self.reject(id, index, "Alert time must be in the future", reply); return }
          let content = UNMutableNotificationContent(); content.title = draft["title"] as? String ?? "ZSWatch alert"
          content.body = "Your ZSWatch alert is due."; content.sound = .default
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(ms - CompanionJournal.now) / 1000), repeats: false)
          let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
          self.admit(id, index, reply) { center.add(request) { error in
            if error == nil { self.complete(id, index, ["platformId": identifier, "targetType": draft["actionType"]!], reply) }
            else { self.unknown(reply) }
          } }
        }
      }
    }
  }
  private func undo(_ id: String, _ index: Int, _ key: String, _ action: [String: Any], _ reply: @escaping (Any?) -> Void) {
    guard let draft = action["draft"] as? [String: Any], let type = draft["actionType"] as? String,
          let response = action["response"] as? [String: Any], let identifier = response["platformId"] as? String else { unknown(reply); return }
    authorize(type) { granted in
      guard granted else { self.unknown(reply); return }
      do {
        if let item = self.store.calendarItem(withIdentifier: identifier) {
          guard item.url == URL(string: "zswatch-action://" + key) else { self.unknown(reply); return }
          if let event = item as? EKEvent { try self.store.remove(event, span: .thisEvent, commit: true) }
          else if let reminder = item as? EKReminder { try self.store.remove(reminder, commit: true) }
        }
        self.owner.queue.async {
          do { try self.owner.voice?.jobs.finishUndo(id, index: index); self.owner.journalChanged(); reply(nil) }
          catch { self.unknown(reply) }
        }
      } catch { self.unknown(reply) }
    }
  }
}

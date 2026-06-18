import WebKit
import EventKit
import UserNotifications
import UIKit

/// Receives `nativeCall(...)` messages from the WebView and performs the
/// native action, replying with a JSON-serializable result (or an error).
final class NativeBridge: NSObject, WKScriptMessageHandlerWithReply {

    /// Tracks the currently rendered HTML so WebView only reloads on change.
    var lastHTML: String = ""

    private let eventStore = EKEventStore()

    // MARK: WKScriptMessageHandlerWithReply

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard
            let dict = message.body as? [String: Any],
            let action = dict["action"] as? String
        else {
            replyHandler(nil, "Malformed bridge message.")
            return
        }
        let payload = dict["payload"] as? [String: Any] ?? [:]

        Task { @MainActor in
            do {
                let result = try await self.handle(action: action, payload: payload)
                replyHandler(result, nil)
            } catch {
                replyHandler(nil, error.localizedDescription)
            }
        }
    }

    // MARK: Dispatch

    @MainActor
    private func handle(action: String, payload: [String: Any]) async throws -> Any? {
        switch action {
        case "calendar.list": return try await listEvents(days: payload["days"] as? Int ?? 1)
        case "calendar.add":  return try await addEvent(payload)
        case "notify":        return try await scheduleNotification(payload)
        case "whatsapp":      return try openWhatsApp(payload)
        case "haptic":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return ["ok": true]
        default:
            throw bridgeError("Unknown action: \(action)")
        }
    }

    // MARK: Calendar

    private func ensureCalendarAccess() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else { throw bridgeError("Calendar access was denied.") }
        } else {
            let granted: Bool = try await withCheckedThrowingContinuation { cont in
                eventStore.requestAccess(to: .event) { ok, err in
                    if let err = err { cont.resume(throwing: err) }
                    else { cont.resume(returning: ok) }
                }
            }
            guard granted else { throw bridgeError("Calendar access was denied.") }
        }
    }

    private func listEvents(days: Int) async throws -> [String: Any] {
        try await ensureCalendarAccess()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: max(1, days), to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let iso = ISO8601DateFormatter()
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { e -> [String: Any] in
                [
                    "title": e.title ?? "(no title)",
                    "start": iso.string(from: e.startDate),
                    "end": iso.string(from: e.endDate),
                    "calendar": e.calendar.title
                ]
            }
        return ["events": events]
    }

    private func addEvent(_ p: [String: Any]) async throws -> [String: Any] {
        try await ensureCalendarAccess()
        let iso = ISO8601DateFormatter()
        guard
            let title = p["title"] as? String, !title.isEmpty,
            let startStr = p["start"] as? String, let start = iso.date(from: startStr)
        else {
            throw bridgeError("calendar.add needs a title and an ISO8601 start date.")
        }
        let end = (p["end"] as? String).flatMap { iso.date(from: $0) } ?? start.addingTimeInterval(3600)

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = p["notes"] as? String
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
        return ["ok": true]
    }

    // MARK: Notifications

    private func scheduleNotification(_ p: [String: Any]) async throws -> [String: Any] {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw bridgeError("Notifications are not allowed for Forge.") }

        let content = UNMutableNotificationContent()
        content.title = p["title"] as? String ?? "Reminder"
        content.body = p["body"] as? String ?? ""
        content.sound = .default

        let iso = ISO8601DateFormatter()
        let fireDate = (p["date"] as? String).flatMap { iso.date(from: $0) }
            ?? Date().addingTimeInterval(60)
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: trigger)
        try await center.add(request)
        return ["ok": true]
    }

    // MARK: WhatsApp (outbound deep link only — see README)

    private func openWhatsApp(_ p: [String: Any]) throws -> [String: Any] {
        let phone = (p["phone"] as? String ?? "").filter { $0.isNumber }
        let text = p["text"] as? String ?? ""
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var urlString = "https://wa.me/\(phone)"
        if !encoded.isEmpty { urlString += "?text=\(encoded)" }
        guard let url = URL(string: urlString) else {
            throw bridgeError("Could not build the WhatsApp URL.")
        }
        UIApplication.shared.open(url)
        return ["ok": true]
    }

    // MARK: Helpers

    private func bridgeError(_ message: String) -> NSError {
        NSError(domain: "Forge.Bridge", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

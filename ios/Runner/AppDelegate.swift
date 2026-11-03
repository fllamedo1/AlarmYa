import Flutter
import UIKit
import AVFoundation
import AppIntents
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      print("AlarmIA: no se pudo activar AVAudioSession: \(error)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

@available(iOS 16.0, *)
struct CrearAlarmaIntent: AppIntent {
  static let title: LocalizedStringResource = "Crear alarma en AlarmIA"
  static let description = IntentDescription(
    "Crea una alarma de una sola vez con la hora y el nombre indicados."
  )
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Hora de la alarma")
  var hora: Date

  @Parameter(title: "Nombre", default: "Alarma")
  var nombre: String

  func perform() async throws -> some IntentResult {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: hora)
    let minute = calendar.component(.minute, from: hora)
    let id = UUID().uuidString.lowercased()
    let normalizedName = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    let alarmName = normalizedName.isEmpty ? "Alarma" : normalizedName
    let alarm: [String: Any] = [
      "id": id,
      "titulo": alarmName,
      "hora": hour,
      "minuto": minute,
      "activa": true,
      "mision": 0,
      "dificultad": 1,
      "cuentasMatematicas": 1,
      "sacudidas": 10,
      "permitirPosponer": true,
      "sonido": "klaxon",
      "volumen": 1.0,
      "dias": [],
    ]

    let stored = UserDefaults.standard.string(forKey: "alarmas_v1")
    var alarms: [[String: Any]] = []
    if let stored,
       let data = stored.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      alarms = decoded
    }
    alarms.append(alarm)
    if let data = try? JSONSerialization.data(withJSONObject: alarms),
       let encoded = String(data: data, encoding: .utf8) {
      UserDefaults.standard.set(encoded, forKey: "alarmas_v1")
    }

    let content = UNMutableNotificationContent()
    content.title = "⏰ \(alarmName)"
    content.body = "Es hora de despertarte"
    content.sound = UNNotificationSound(named: UNNotificationSoundName("klaxon.wav"))

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    if let scheduled = Calendar.current.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: Date()
    ), scheduled <= Date() {
      let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      components.day = calendar.component(.day, from: tomorrow)
      components.month = calendar.component(.month, from: tomorrow)
      components.year = calendar.component(.year, from: tomorrow)
    }

    let request = UNNotificationRequest(
      identifier: "alarmya-siri-\(id)",
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    )
    try await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    )
    try await UNUserNotificationCenter.current().add(request)
    return .result(dialog: "Alarma \(alarmName) creada para las \(String(format: "%02d:%02d", hour, minute)).")
  }
}

@available(iOS 16.0, *)
struct AlarmIShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CrearAlarmaIntent(),
      phrases: [
        "Crear una alarma en \(.applicationName)",
        "Configurar una alarma en \(.applicationName)",
      ],
      shortTitle: "Crear alarma",
      systemImageName: "alarm"
    )
  }
}

import AppKit
import IOKit
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
  @ObservedObject var desktop: LiveDesktop
  @ObservedObject private var starRequest = StarRequest.shared
  @State private var screenRecordingAllowed = CGPreflightScreenCaptureAccess()
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        hero
        VStack(spacing: 16) {
          if starRequest.isVisible {
            SettingsGroup { StarRow() }
              .transition(.opacity)
          }
          foldingCard
          PreferencesCard()
        }
        .padding(.horizontal, 20)
        footer
      }
      .frame(maxWidth: .infinity)
    }
    .frame(width: 440)
    .frame(minHeight: 480, idealHeight: 680)
    .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    .background(MainWindowChrome())
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in
      screenRecordingAllowed = CGPreflightScreenCaptureAccess()
    }
  }

  private var hero: some View {
    HStack(alignment: .center, spacing: 8) {
      LidPicture(
        lid: desktop.lid, openAngle: desktop.openAngle, active: desktop.isActive,
        available: desktop.sensorAvailable, folding: desktop.isFolding, scale: 3.6
      )
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: "Softfold")
          .font(.system(size: 20, weight: .semibold))
        Text("Your desktop follows your lid.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.leading, 12)
    .padding(.trailing, 16)
    .padding(.top, 4)
    .padding(.bottom, 6)
  }

  private var foldingCard: some View {
    SettingsGroup(
      footnote: String(
        localized:
          "Folding begins below this angle. Softfold takes it from your lid the first time you turn it on."
      )
    ) {
      SettingsRow(
        "power", tint: desktop.isActive ? .green : .gray, title: desktop.statusTitle,
        subtitle: desktop.statusSubtitle
      ) {
        Toggle(
          "Turn Softfold on or off",
          isOn: Binding(get: { desktop.isEnabled }, set: { desktop.setEnabled($0) })
        )
        .toggleStyle(.switch)
        .labelsHidden()
        .disabled(desktop.isStarting)
      }
      if !screenRecordingAllowed, !desktop.needsPermission {
        SettingsDivider()
        SettingsRow(
          "rectangle.dashed.badge.record", tint: .red,
          title: String(localized: "Screen Recording"),
          subtitle: String(
            localized:
              "Softfold reads your display only to draw the fold. Frames stay in memory on your Mac."
          )
        ) {
          Button("Open Settings", action: openScreenRecordingSettings)
            .controlSize(.small)
        }
      }
      if let error = desktop.error {
        SettingsDivider()
        SettingsRow("exclamationmark.triangle.fill", tint: .orange, title: error) {
          if desktop.needsPermission {
            Button("Open Settings", action: openScreenRecordingSettings)
              .controlSize(.small)
          }
        }
      }
      SettingsDivider()
      SettingsRow(
        "angle", tint: .indigo, title: String(localized: "Open position"),
        subtitle: degrees(desktop.openAngle)
      ) {
        if !desktop.isDefaultOpenAngle {
          Button("Restore Default") {
            withAnimation(.smooth(duration: 0.4)) { desktop.restoreDefaultOpenPosition() }
          }
          .controlSize(.small)
          .fixedSize()
          .help(Text("Go back to \(degrees(LiveDesktop.defaultOpenAngle))"))
        }
        Button("Use Current Angle") {
          withAnimation(.smooth(duration: 0.4)) { desktop.setOpenPosition() }
        }
        .controlSize(.small)
        .fixedSize()
        .disabled(!desktop.sensorAvailable || desktop.isStarting)
        .help("Save the lid angle you are viewing at right now")
      }
      SettingsDivider()
      SettingsRow(
        "camera.aperture", tint: .teal, title: String(localized: "Sharpen when you stop"),
        subtitle: String(localized: "Pause partway and the desktop comes back into focus.")
      ) {
        Toggle(
          "Sharpen when you stop",
          isOn: Binding(get: { desktop.focusesWhenHeld }, set: { desktop.setFocusesWhenHeld($0) })
        )
        .toggleStyle(.switch)
        .labelsHidden()
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 6) {
      Button {
        openWindow(id: "about")
      } label: {
        Text(verbatim: "Softfold \(version)")
      }
      .buttonStyle(.plain)
      .help("About Softfold")
    }
    .font(.system(size: 11))
    .foregroundStyle(.secondary)
    .padding(.top, 18)
    .padding(.bottom, 20)
  }

  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }
}

extension LiveDesktop {
  var statusTitle: String {
    if isActive { return String(localized: "On") }
    if isStarting { return String(localized: "Starting…") }
    return isEnabled ? String(localized: "Waiting…") : String(localized: "Off")
  }

  var statusSubtitle: String {
    if isActive { return String(localized: "Your desktop bends as the lid closes.") }
    if isStarting { return String(localized: "Getting the desktop and the sensor ready.") }
    if isWaitingForDisplay {
      return String(localized: "Waiting for the built-in display to turn on.")
    }
    if !sensorAvailable { return String(localized: "Waiting for the lid angle sensor.") }
    if isEnabled { return String(localized: "Softfold is on but not running yet.") }
    return String(localized: "Turn Softfold on to follow the lid.")
  }
}

func degrees(_ value: Double) -> String {
  Measurement(value: value, unit: UnitAngle.degrees).formatted(
    .measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))
}

struct MacLook {
  enum Model {
    case pro14
    case pro16
    case air13
    case air15
  }

  enum Port {
    case magSafe
    case thunderbolt
    case headphone
  }

  struct Chassis {
    let isPro: Bool
    let depth: Double
    let baseHeight: Double
    let lidMetal: Double
    let lidGlass: Double
    let lidCorner: Double
    let curveHeight: Double
    let curveWidth: Double
    let portCenter: Double
    let ports: [(port: Port, center: Double)]
    let feet: [Double]
    let footTop: Double
    let footBottom: Double
    let footHeight: Double
    let vent: ClosedRange<Double>?
    let hingeDrop: Double
    let hingeGap: Double
    let displayHeight: Double
    let topBezel: Double
    var lidThickness: Double { lidMetal + lidGlass }
  }

  let model: Model
  let color: Int

  static let current = detect()
  static let pointsPerCentimeter: CGFloat = 4.6

  var chassis: Chassis {
    switch model {
    case .pro14:
      return Chassis(
        isPro: true, depth: 22.12, baseHeight: 1.11, lidMetal: 0.37, lidGlass: 0.045,
        lidCorner: 0.16, curveHeight: 0.62, curveWidth: 0.9, portCenter: 0.37,
        ports: [(.magSafe, 2.81), (.thunderbolt, 4.63), (.thunderbolt, 6.12), (.headphone, 7.41)],
        feet: [1.716, 18.337], footTop: 2.07, footBottom: 1.79, footHeight: 0.15,
        vent: 9.07...19.48, hingeDrop: 0.70, hingeGap: 0.18,
        displayHeight: 19.64, topBezel: 0.56)
    case .pro16:
      return Chassis(
        isPro: true, depth: 24.81, baseHeight: 1.22, lidMetal: 0.39, lidGlass: 0.07,
        lidCorner: 0.16, curveHeight: 0.62, curveWidth: 0.9, portCenter: 0.375,
        ports: [(.magSafe, 3.58), (.thunderbolt, 5.43), (.thunderbolt, 6.93), (.headphone, 8.21)],
        feet: [1.72, 21.03], footTop: 2.05, footBottom: 1.79, footHeight: 0.15,
        vent: 9.81...22.42, hingeDrop: 0.76, hingeGap: 0.24,
        displayHeight: 22.34, topBezel: 0.54)
    case .air13:
      return Chassis(
        isPro: false, depth: 21.5, baseHeight: 0.74, lidMetal: 0.32, lidGlass: 0.06,
        lidCorner: 0.07, curveHeight: 0.37, curveWidth: 0.45, portCenter: 0.22,
        ports: [(.magSafe, 2.27), (.thunderbolt, 4.14), (.thunderbolt, 5.64)],
        feet: [1.43, 18.02], footTop: 1.98, footBottom: 1.76, footHeight: 0.14,
        vent: nil, hingeDrop: 0.52, hingeGap: 0.09,
        displayHeight: 18.87, topBezel: 0.64)
    case .air15:
      return Chassis(
        isPro: false, depth: 23.76, baseHeight: 0.76, lidMetal: 0.32, lidGlass: 0.06,
        lidCorner: 0.07, curveHeight: 0.37, curveWidth: 0.45, portCenter: 0.21,
        ports: [(.magSafe, 3.30), (.thunderbolt, 5.11), (.thunderbolt, 6.58)],
        feet: [1.49, 20.22], footTop: 2.00, footBottom: 1.80, footHeight: 0.14,
        vent: nil, hingeDrop: 0.52, hingeGap: 0.09,
        displayHeight: 21.14, topBezel: 0.68)
    }
  }

  var finish: (red: Double, green: Double, blue: Double) {
    let isPro = model == .pro14 || model == .pro16
    let hex: UInt32
    switch color {
    case 2 where isPro: hex = 0xBCBCBF
    case 2: hex = 0xB0B0B3
    case 7: hex = 0x59626F
    case 8: hex = 0xE9E2D8
    case 9: hex = 0x555257
    case 11: hex = 0xCCD8DF
    default: hex = 0xDFE0E2
    }
    return (
      Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255
    )
  }

  func shade(_ factor: Double) -> Color {
    let base = finish
    return Color(
      .sRGB, red: min(base.red * factor, 1), green: min(base.green * factor, 1),
      blue: min(base.blue * factor, 1))
  }

  private static func detect() -> MacLook {
    let model = hardwareModel()
    let color = housingColor() ?? 1
    let deviceModel = UTTagClass(rawValue: "com.apple.device-model-code")
    let identifier =
      UTType(tag: "\(model)@ECOLOR=\(color)", tagClass: deviceModel, conformingTo: nil)?.identifier
      ?? ""
    let kind: Model
    if identifier.contains("macbookair-15") {
      kind = .air15
    } else if identifier.contains("macbookair") || model.hasPrefix("MacBookAir") {
      kind = .air13
    } else if identifier.contains("macbookpro-16") {
      kind = .pro16
    } else {
      kind = .pro14
    }
    return MacLook(model: kind, color: color)
  }

  private static func hardwareModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var buffer = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buffer, &size, nil, 0)
    return String(cString: buffer)
  }

  private static func housingColor() -> Int? {
    let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/chosen")
    guard entry != 0 else { return nil }
    defer { IOObjectRelease(entry) }
    guard
      let data = IORegistryEntryCreateCFProperty(
        entry, "housing-color" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? Data,
      data.count >= 4
    else { return nil }
    let value = data.suffix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    return Int(value)
  }
}

struct MainWindowChrome: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      guard let window = view.window else { return }
      window.minSize = NSSize(width: 440, height: 480)
      window.maxSize = NSSize(width: 440, height: CGFloat.greatestFiniteMagnitude)
      if window.frame.width != 440 {
        var frame = window.frame
        frame.size.width = 440
        window.setFrame(frame, display: true)
      }
    }
    return view
  }

  func updateNSView(_ view: NSView, context: Context) {}
}

import SwiftUI

struct PreferencesCard: View {
  @AppStorage(DockIcon.key) private var showsInDock = false
  @AppStorage("showsMenuBarIcon") private var showsMenuBarIcon = true

  var body: some View {
    SettingsGroup {
      SettingsRow(
        "menubar.rectangle", tint: .gray, title: String(localized: "Show in menu bar"),
        subtitle: showsMenuBarIcon
          ? nil : String(localized: "Open Softfold again to come back here.")
      ) {
        Toggle("Show in menu bar", isOn: $showsMenuBarIcon)
          .toggleStyle(.switch)
          .labelsHidden()
      }
      SettingsDivider()
      SettingsRow("dock.rectangle", tint: .gray, title: String(localized: "Show in Dock")) {
        Toggle("Show in Dock", isOn: $showsInDock)
          .toggleStyle(.switch)
          .labelsHidden()
          .onChange(of: showsInDock) { DockIcon.apply() }
      }
      SettingsDivider()
      SettingsRow(
        "globe", tint: .indigo, title: String(localized: "Language"),
        subtitle: String(localized: "Relaunch Softfold to switch languages.")
      ) {
        Button("Relaunch", action: AppLanguage.relaunch)
          .controlSize(.small)
        Picker(
          "Language",
          selection: Binding(
            get: { AppLanguage.current },
            set: { AppLanguage.choose($0) }))
        {
          Text("System Language").tag("")
          ForEach(AppLanguage.available, id: \.self) { code in
            Text(verbatim: AppLanguage.name(of: code)).tag(code)
          }
        }
        .labelsHidden()
        .fixedSize()
        .controlSize(.small)
      }
    }
  }
}

enum DockIcon {
  static let key = "showsInDock"

  static func apply() {
    let policy: NSApplication.ActivationPolicy =
      UserDefaults.standard.bool(forKey: key) ? .regular : .accessory
    guard NSApp.activationPolicy() != policy else { return }
    NSApp.setActivationPolicy(policy)
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
  }
}

private enum AppLanguage {
  static var current: String {
    let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    return (domain?["AppleLanguages"] as? [String])?.first ?? ""
  }

  static let available = Set(Bundle.main.localizations).subtracting(["Base"]).sorted {
    name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending
  }

  static func name(of code: String) -> String {
    let locale = Locale(identifier: code)
    return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
  }

  static func choose(_ code: String) {
    if code.isEmpty {
      UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    } else {
      UserDefaults.standard.set([code], forKey: "AppleLanguages")
    }
  }

  static func relaunch() {
    let reopen = Process()
    reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
    reopen.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
    try? reopen.run()
    NSApp.terminate(nil)
  }
}

struct AboutView: View {
  private static let icon: CGFloat = 240

  var body: some View {
    VStack(spacing: 0) {
      Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
        .resizable()
        .interpolation(.high)
        .frame(width: Self.icon * 1024 / 980, height: Self.icon * 1024 / 980)
        .frame(width: Self.icon, height: Self.icon)
        .clipShape(RoundedRectangle(cornerRadius: Self.icon * 262 / 980, style: .circular))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .padding(.top, 40)
        .padding(.bottom, 6)
        .accessibilityHidden(true)
      Text(verbatim: "Softfold")
        .font(.system(size: 24, weight: .semibold))
        .padding(.top, 8)
      Text("Your desktop follows your lid.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 36)
        .padding(.top, 6)
      HStack(spacing: 6) {
        Text("Version \(versionLabel)")
      }
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .padding(.top, 20)
      Text(verbatim: "© 2026 Reff Wu")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
        .padding(.bottom, 28)
    }
    .frame(width: 360)
    .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    .background(AboutWindowChrome())
  }

  private var versionLabel: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info?["CFBundleVersion"] as? String, !build.isEmpty else { return version }
    return "\(version) (\(build))"
  }
}

private struct AboutWindowChrome: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      view.window?.styleMask.remove([.miniaturizable, .resizable])
    }
    return view
  }

  func updateNSView(_ view: NSView, context: Context) {}
}

@MainActor
final class StarRequest: ObservableObject {
  static let shared = StarRequest()
  @Published private(set) var isVisible = false
  private let defaults = UserDefaults.standard

  private init() { update() }

  func recordFold() {
    guard !defaults.bool(forKey: "starAnswered") else { return }
    defaults.set(defaults.integer(forKey: "foldCount") + 1, forKey: "foldCount")
    let day = Date().ISO8601Format(.iso8601Date(timeZone: .current))
    var days = defaults.stringArray(forKey: "foldDays") ?? []
    if !days.contains(day), days.count < 2 {
      days.append(day)
      defaults.set(days, forKey: "foldDays")
    }
    update()
  }

  func star() {
    if let project = URL(string: "https://github.com/ReffWu/softfold") {
      NSWorkspace.shared.open(project)
    }
    close()
  }

  func close() {
    defaults.set(true, forKey: "starAnswered")
    withAnimation(.smooth(duration: 0.3)) { update() }
  }

  private func update() {
    isVisible =
      !defaults.bool(forKey: "starAnswered") && defaults.integer(forKey: "foldCount") >= 5
      && (defaults.stringArray(forKey: "foldDays") ?? []).count >= 2
  }
}

struct StarRow: View {
  @ObservedObject private var request = StarRequest.shared

  var body: some View {
    SettingsRow(
      "star.fill", tint: .yellow, title: String(localized: "Enjoying Softfold?"),
      subtitle: String(
        localized: "It’s free and open source. A star on GitHub helps more people find it.")
    ) {
      Button("Star") { request.star() }
        .controlSize(.small)
        .fixedSize()
      Button {
        request.close()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .accessibilityLabel(Text("Close"))
      .help(Text("Close"))
    }
  }
}

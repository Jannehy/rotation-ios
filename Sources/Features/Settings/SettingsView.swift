import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: Session
    @State private var discoverable = true
    @AppStorage(Accent.key) private var accentName = Accent.sunset.rawValue
    @AppStorage("season.always") private var seasonAlways = false
    @AppStorage("season.remind") private var seasonRemind = true

    var body: some View {
        NavigationStack {
            List {
                if session.isDemo {
                    Section {
                        Label("You are looking at the demo.", systemImage: "wand.and.stars")
                            .foregroundStyle(Palette.accent)
                        Text("The numbers come from an invented library that ships with the app. Connect your own Rotation server to see your own.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button(String(localized: "Connect a server")) { session.signOut() }
                    }
                } else {
                    Section(String(localized: "Account")) {
                        row(String(localized: "User"), session.me?.user.name ?? "–")
                        if let bounds = session.me?.bounds, bounds.firstPlay > 0 {
                            row(String(localized: "History since"),
                                Date(timeIntervalSince1970: TimeInterval(bounds.firstPlay))
                                    .formatted(date: .abbreviated, time: .omitted))
                            row(String(localized: "Plays in total"),
                                Format.number(bounds.historyPlays))
                        }
                        row(String(localized: "Server"), session.serverAddress ?? "–")
                    }

                    Section {
                        Toggle(String(localized: "Findable by others"), isOn: $discoverable)
                            .tint(Palette.accent)
                            .onChange(of: discoverable) { value in
                                Task {
                                    _ = await session.perform {
                                        try await session.source?.setDiscoverable(value)
                                    }
                                }
                            }
                    } footer: {
                        Text("Switched off you appear in no suggestion list. Existing friendships stay.")
                    }

                    Section {
                        Button(String(localized: "Sign out"), role: .destructive) {
                            session.signOut()
                        }
                        Button(String(localized: "Use a different server")) {
                            session.forgetServer()
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        ForEach(Accent.allCases) { option in
                            Button {
                                accentName = option.rawValue
                                Accent.applyIcon(option)
                            } label: {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [option.accent, option.second],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(.primary,
                                                        lineWidth: accentName == option.rawValue ? 2 : 0)
                                            .padding(-3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Colour")
                } footer: {
                    Text("The app icon follows along.")
                }

                Section {
                    Toggle(String(localized: "Show the story on the recap page all year"),
                           isOn: $seasonAlways)
                        .tint(Palette.accent)
                    Toggle(String(localized: "Remind me about the recap"), isOn: $seasonRemind)
                        .tint(Palette.accent)
                        .onChange(of: seasonRemind) { value in
                            Task {
                                if value {
                                    // The switch follows the system's answer,
                                    // not the other way round.
                                    seasonRemind = await SeasonReminder.enable()
                                } else {
                                    SeasonReminder.cancel()
                                }
                            }
                        }
                } header: {
                    Text("Recap")
                } footer: {
                    Text("The recap announces itself on the home screen from 1 December to 31 January. The switch above is about the button on the recap page; the reminder arrives on 1 December.")
                }

                Section(String(localized: "About")) {
                    row("Rotation", session.me?.version ?? "–")
                    Link(destination: URL(string: "https://github.com/Jannehy/rotation")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("Every number comes from your Navidrome server's play history. Rotation only ever reads it.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
        .task { discoverable = session.me?.discoverable ?? true }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.footnote.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

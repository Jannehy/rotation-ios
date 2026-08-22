import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: Session
    @State private var username = ""
    @State private var password = ""
    @FocusState private var field: Field?

    private enum Field { case user, pass }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            RecordMark(size: 64)
            Text("Rotation")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .padding(.top, 12)
            Text("Your Navidrome credentials.")
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 2)

            VStack(spacing: 12) {
                TextField(String(localized: "Username"), text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .user)
                    .submitLabel(.next)
                    .onSubmit { field = .pass }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                SecureField(String(localized: "Password"), text: $password)
                    .textContentType(.password)
                    .focused($field, equals: .pass)
                    .submitLabel(.go)
                    .onSubmit(signIn)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: signIn) {
                    HStack {
                        Spacer()
                        if session.isWorking { ProgressView().tint(.black) }
                        Text("Sign in").fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .background(Palette.accent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(username.isEmpty || password.isEmpty || session.isWorking)

                if let error = session.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 18) {
                    Button(String(localized: "Different server")) { session.forgetServer() }
                    Button(String(localized: "Look around first")) { session.startDemo() }
                }
                .font(.caption)
                .padding(.top, 6)
            }
            .padding(.top, 24)
            .padding(.horizontal, 28)

            Spacer()
            Text(session.serverAddress ?? "")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .padding(.bottom, 22)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { username = session.username ?? "" }
    }

    private func signIn() {
        field = nil
        Task { await session.signIn(username: username, password: password) }
    }
}

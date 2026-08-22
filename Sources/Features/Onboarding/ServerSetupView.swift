import SwiftUI

/// First screen: where does your Rotation live – or would you rather look
/// around first?
struct ServerSetupView: View {
    @EnvironmentObject private var session: Session
    @State private var address = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            RecordMark(size: 76)
            Text("Rotation")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .padding(.top, 14)
            Text("Listening statistics for your Navidrome server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            VStack(spacing: 12) {
                TextField("rotation.example.org", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($addressFocused)
                    .submitLabel(.go)
                    .onSubmit(connect)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: connect) {
                    HStack {
                        Spacer()
                        if session.isWorking { ProgressView().tint(.black) }
                        Text("Connect").fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .background(Palette.accent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(address.isEmpty || session.isWorking)

                if let error = session.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    session.startDemo()
                } label: {
                    Text("Look around first")
                        .font(.footnote)
                        .underline()
                }
                .padding(.top, 4)
            }
            .padding(.top, 26)
            .padding(.horizontal, 28)

            Spacer()
            Text("Rotation reads the play history of a Navidrome server you host yourself.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { address = session.serverAddress ?? "" }
    }

    private func connect() {
        addressFocused = false
        Task { _ = await session.connect(to: address) }
    }
}

/// The app's mark: a record, drawn rather than shipped as an image.
struct RecordMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            ForEach([0.78, 0.60, 0.42], id: \.self) { ratio in
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: size * 0.025)
                    .frame(width: size * ratio, height: size * ratio)
            }
            Circle().fill(Palette.accent).frame(width: size * 0.24, height: size * 0.24)
            Circle().fill(Color.black).frame(width: size * 0.07, height: size * 0.07)
        }
        .frame(width: size, height: size)
    }
}

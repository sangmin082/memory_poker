import SwiftUI

/// 온라인 대전 로비 — 방을 만들어 코드를 보내거나, 받은 코드로 들어간다.
struct OnlineLobbyView: View {
    @State private var client = RoomClient()
    @State private var joinCode = ""
    @State private var game: GameModel?
    @State private var showGame = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("온라인 대전")
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 12)

                    Text("같은 카드를 동시에 외우고, 각자의 기기에서 고릅니다")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 6)
                        .padding(.bottom, 24)

                    createSection
                    joinSection
                    Rectangle().fill(Theme.hairline).frame(height: 1)

                    statusSection
                        .padding(.top, 18)
                }
                .padding(.horizontal, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .navigationDestination(isPresented: $showGame) {
            if let game {
                GameScreen(model: game)
            }
        }
        .onChange(of: client.state) { _, newState in
            if case .matched = newState, game == nil {
                isCodeFocused = false
                game = GameModel(mode: .online, client: client)
                showGame = true
            }
        }
        .onChange(of: showGame) { _, isShowing in
            // 대전 화면에서 돌아오면 방은 이미 닫혀 있다. 다시 하려면 새 방을 만든다.
            if !isShowing {
                game = nil
                client.close()
                joinCode = ""
            }
        }
        .onDisappear {
            if !showGame { client.close() }
        }
    }

    // MARK: - 방 만들기

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Theme.hairline).frame(height: 1)

            Text("방 만들기")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)

            if case .waitingForOpponent(let code) = client.state {
                HStack(alignment: .center, spacing: 14) {
                    Text(verbatim: code)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(Theme.accent)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("room-code")
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        Haptics.tap()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel(Text("코드 복사"))
                    ShareLink(item: String(localized: "기억 포커 대결 초대! 방 코드: \(code)")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("코드 보내기"))
                }
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)

                HStack(spacing: 8) {
                    ProgressView().tint(Theme.ink)
                    Text("상대의 입장을 기다리는 중…")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                Button("방 닫기") { client.close() }
                    .buttonStyle(InkButtonStyle())
            } else {
                Text("6자리 코드가 만들어집니다. 코드를 친구에게 보내 주세요.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)

                Button("새 방 만들기") {
                    isCodeFocused = false
                    client.createRoom()
                }
                .buttonStyle(InkButtonStyle(filled: true))
                .disabled(isBusy)
                .opacity(isBusy ? 0.35 : 1)
            }
        }
        .padding(.bottom, 22)
    }

    // MARK: - 코드로 입장

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Theme.hairline).frame(height: 1)

            Text("코드로 입장")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)

            HStack(spacing: 12) {
                TextField("방 코드 6자리", text: $joinCode)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.join)
                    .focused($isCodeFocused)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Theme.ink.opacity(0.5), lineWidth: 1.5)
                    )
                    .onChange(of: joinCode) { _, newValue in
                        let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                            .prefix(OnlineConfig.codeLength))
                        if cleaned != newValue { joinCode = cleaned }
                    }
                    .onSubmit(join)
                    .accessibilityIdentifier("join-code")

                Button("입장", action: join)
                    .buttonStyle(InkButtonStyle(filled: true))
                    .frame(width: 92)
                    .disabled(!canJoin)
                    .opacity(canJoin ? 1 : 0.35)
            }
        }
        .padding(.bottom, 22)
    }

    private var canJoin: Bool { joinCode.count == OnlineConfig.codeLength && !isBusy }

    private func join() {
        guard canJoin else { return }
        isCodeFocused = false
        client.joinRoom(code: joinCode)
    }

    // MARK: - 상태

    @ViewBuilder
    private var statusSection: some View {
        switch client.state {
        case .connecting:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.ink)
                    Text("연결 중…")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                }
                Text("서버가 쉬고 있었다면 깨우는 데 1분쯤 걸릴 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        case .failed(let failure):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(Self.message(for: failure))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote)
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("lobby-error")
        case .idle, .waitingForOpponent, .matched, .opponentLeft:
            Text("대전 중에 카드가 공개된 화면을 캡처하면 그 판은 몰수패입니다.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private static func message(for failure: RoomClient.Failure) -> LocalizedStringKey {
        switch failure {
        case .cannotConnect: return "서버에 연결할 수 없습니다. 인터넷 연결을 확인해 주세요."
        case .disconnected: return "서버와 연결이 끊어졌습니다."
        case .roomNotFound: return "없는 방 코드입니다. 코드를 다시 확인해 주세요."
        case .roomFull: return "이미 두 사람이 들어간 방입니다."
        case .wrongGame: return "다른 게임의 방 코드입니다."
        case .other: return "문제가 생겼습니다. 다시 시도해 주세요."
        }
    }

    private var isBusy: Bool {
        switch client.state {
        case .idle, .failed, .opponentLeft: return false
        case .connecting, .waitingForOpponent, .matched: return true
        }
    }
}

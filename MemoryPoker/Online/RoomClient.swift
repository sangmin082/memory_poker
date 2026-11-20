import Foundation
import Observation

/// 방 코드로 만나는 2인 온라인 대전 클라이언트.
/// 중계 서버와 WebSocket(JSON)으로 통신한다. 방을 만들면 6자리 코드를 받고,
/// 상대가 그 코드로 들어오면 연결된다. 그 뒤로는 OnlineMessage를 서로 주고받는다.
@MainActor
@Observable
final class RoomClient {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        /// 방 생성 완료 — 상대 입장 대기 중
        case waitingForOpponent(code: String)
        /// 상대와 연결됨. 방을 만든 쪽이 방장(판을 정하는 쪽).
        case matched(isHost: Bool)
        case opponentLeft
        case failed(Failure)
    }

    enum Failure: Equatable {
        case cannotConnect
        case disconnected
        case roomNotFound
        case roomFull
        /// 같은 서버를 쓰는 다른 게임의 방
        case wrongGame
        case other
    }

    private(set) var state: ConnectionState = .idle
    /// 상대의 메시지가 도착하면 호출된다
    @ObservationIgnored var onMessage: ((OnlineMessage) -> Void)?
    /// 상대가 방을 나가거나 연결이 끊기면 호출된다
    @ObservationIgnored var onOpponentLeft: (() -> Void)?

    @ObservationIgnored private var task: URLSessionWebSocketTask?
    @ObservationIgnored private var isHost = false
    /// 연결 확인(ping)을 돌리고 있는 소켓
    @ObservationIgnored private var heartbeatTask: URLSessionWebSocketTask?

    /// 서버가 쉬다가 깨어나는 시간까지 기다려 주는 연결 제한 시간(초)
    private static let connectTimeout: Double = 75
    private static let pingInterval: Double = 10
    private static let pingTimeout: Double = 8

    // MARK: - 서버 프로토콜

    /// 서버 → 클라이언트 봉투. move의 내용은 따로 읽는다(다른 게임의 메시지일 수 있다).
    private struct Envelope: Decodable {
        let type: String
        let code: String?
        let message: String?
    }

    private struct MoveEnvelope: Decodable {
        let move: OnlineMessage
    }

    private struct Outgoing: Encodable {
        let type: String
        var code: String?
        var move: OnlineMessage?
    }

    // MARK: - 연결

    func createRoom() {
        connect(isHost: true, first: Outgoing(type: "create"))
    }

    func joinRoom(code: String) {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        connect(isHost: false, first: Outgoing(type: "join", code: normalized))
    }

    func send(_ message: OnlineMessage) {
        Task { await send(Outgoing(type: "move", move: message)) }
    }

    func close() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .idle
    }

    private func connect(isHost: Bool, first: Outgoing) {
        close()
        self.isHost = isHost
        state = .connecting
        let task = URLSession.shared.webSocketTask(with: OnlineConfig.serverURL)
        self.task = task
        task.resume()
        Task {
            await send(first)
            await receiveLoop(task)
        }
        // 응답이 끝내 없으면 '연결 중'에 갇히지 않게 한다
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.connectTimeout))
            guard let self, self.task === task, case .connecting = self.state else { return }
            self.fail(.cannotConnect)
        }
    }

    // MARK: - 연결 확인

    /// 주기적으로 ping을 보내, 조용히 끊긴 연결(지하철·와이파이 전환 등)을 알아챈다.
    private func startHeartbeat(_ task: URLSessionWebSocketTask) {
        guard heartbeatTask !== task else { return }
        heartbeatTask = task
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(Self.pingInterval))
                guard let self, self.task === task else { return }
                let alive = await Self.ping(task, timeout: Self.pingTimeout)
                guard self.task === task else { return }
                if !alive {
                    task.cancel(with: .goingAway, reason: nil)
                    self.connectionLost()
                    return
                }
            }
        }
    }

    /// pong이 제한 시간 안에 오면 true
    private nonisolated static func ping(_ task: URLSessionWebSocketTask, timeout: Double) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let once = Once()
            task.sendPing { error in
                if once.claim() { continuation.resume(returning: error == nil) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if once.claim() { continuation.resume(returning: false) }
            }
        }
    }

    /// 한 번만 통과시키는 문
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if claimed { return false }
            claimed = true
            return true
        }
    }

    /// 연결이 끊겼을 때: 대전 중이면 상대가 나간 것으로, 그 전이면 실패로 처리한다.
    private func connectionLost() {
        task = nil
        switch state {
        case .matched:
            state = .opponentLeft
            onOpponentLeft?()
        case .waitingForOpponent:
            state = .failed(.disconnected)
        case .connecting:
            state = .failed(.cannotConnect)
        case .idle, .opponentLeft, .failed:
            break
        }
    }

    // MARK: - 수신

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while self.task === task {
            do {
                let message = try await task.receive()
                guard self.task === task else { return }
                startHeartbeat(task)
                switch message {
                case .string(let text): handle(Data(text.utf8))
                case .data(let data): handle(data)
                @unknown default: break
                }
            } catch {
                guard self.task === task else { return }
                connectionLost()
                return
            }
        }
    }

    private func handle(_ data: Data) {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        switch envelope.type {
        case "room":
            if let code = envelope.code { state = .waitingForOpponent(code: code) }
        case "start":
            state = .matched(isHost: isHost)
        case "move":
            guard case .matched = state else { return }
            if let move = try? JSONDecoder().decode(MoveEnvelope.self, from: data).move {
                onMessage?(move)
            } else {
                // 우리 게임의 메시지가 아니다 → 다른 게임의 방에 들어온 것
                fail(.wrongGame)
            }
        case "left":
            if case .matched = state {
                state = .opponentLeft
                onOpponentLeft?()
            }
        case "error":
            fail(Self.failure(forServerMessage: envelope.message ?? ""))
        default:
            break
        }
    }

    /// 방을 떠나고 실패 상태로 남는다.
    func fail(_ failure: Failure) {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .failed(failure)
    }

    /// 서버의 한국어 오류 문구를 종류로 바꾼다 (화면에서는 앱의 언어로 다시 쓴다).
    private static func failure(forServerMessage message: String) -> Failure {
        if message.contains("존재하지 않는") { return .roomNotFound }
        if message.contains("가득") { return .roomFull }
        return .other
    }

    private func send(_ message: Outgoing) async {
        guard let task else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try await task.send(.string(String(decoding: data, as: UTF8.self)))
        } catch {
            guard self.task === task else { return }
            if case .connecting = state {
                self.task = nil
                state = .failed(.cannotConnect)
            }
        }
    }
}

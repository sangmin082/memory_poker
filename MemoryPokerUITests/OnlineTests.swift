import XCTest

/// 온라인 대전을 끝까지 확인한다. 테스트 프로세스가 WebSocket으로 직접 '상대' 역할을 한다.
/// 실제 중계 서버를 쓰므로, 서버에 닿지 않으면 실패가 아니라 건너뛴다.
///
/// 시드 3번 판: 공유 카드 A♦ A♥ Q♥, 9번(Q♠)·10번(A♣)은 풀하우스, 3번(K♣)·15번(K♠)은 투페어.
private let serverHTTP = URL(string: "https://feast-of-memory.onrender.com/")!
private let serverWS = URL(string: "wss://feast-of-memory.onrender.com")!

@MainActor
final class OnlineTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false

        // 무료 서버는 쉬고 있으면 깨어나는 데 1분쯤 걸린다
        var request = URLRequest(url: serverHTTP)
        request.timeoutInterval = 90
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw XCTSkip("중계 서버가 응답하지 않습니다")
            }
        } catch let skip as XCTSkip {
            throw skip
        } catch {
            throw XCTSkip("중계 서버에 닿지 않습니다: \(error.localizedDescription)")
        }

        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
                               "-uiTestSeed", "3", "-memorizeTime", "3"]
        app.launch()
    }

    // MARK: - 상대 역할

    /// 서버에 직접 붙는 상대
    private final class Peer: @unchecked Sendable {
        let task: URLSessionWebSocketTask

        init() {
            task = URLSession.shared.webSocketTask(with: serverWS)
            task.resume()
        }

        func send(_ object: [String: Any]) async throws {
            let data = try JSONSerialization.data(withJSONObject: object)
            try await task.send(.string(String(decoding: data, as: UTF8.self)))
        }

        func sendMove(_ move: [String: Any]) async throws {
            try await send(["type": "move", "move": move])
        }

        private func receive() async throws -> [String: Any] {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let raw): data = raw
            @unknown default: data = Data()
            }
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }

        /// type이 맞는(그리고 move라면 kind도 맞는) 메시지가 올 때까지 읽는다.
        func wait(type: String, kind: String? = nil, timeout: TimeInterval = 20) async throws -> [String: Any] {
            try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask {
                    while true {
                        let message = try await self.receive()
                        guard message["type"] as? String == type else { continue }
                        if let kind {
                            guard let move = message["move"] as? [String: Any], move["kind"] as? String == kind else { continue }
                            return move
                        }
                        return message
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw NSError(domain: "OnlineTests", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "\(timeout)초 동안 \(type)/\(kind ?? "-") 메시지가 오지 않았습니다",
                    ])
                }
                let first = try await group.next() ?? [:]
                group.cancelAll()
                return first
            }
        }

        func close() {
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    // MARK: - 도우미

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapButton(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "버튼 없음: \(text)", file: file, line: line)
        element.tap()
    }

    private var status: XCUIElement { app.staticTexts["status"] }

    private func card(_ index: Int) -> XCUIElement { app.buttons["card-\(index)"] }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForStatus(_ text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if status.exists, status.label == text { return }
            usleep(200_000)
        }
        XCTFail("status가 '\(text)'가 되지 않았습니다 (지금: \(status.exists ? status.label : "없음"))", file: file, line: line)
    }

    // MARK: - 시나리오

    /// 앱이 방을 만들고(방장), 상대가 코드로 들어온다. 한 판을 이기고, 다음 판은 상대의 암기 위반으로 끝난다.
    func test1_HostPlaysTwoRounds() async throws {
        tapButton("온라인 대전")
        shot("20 온라인 로비")
        tapButton("새 방 만들기")

        let codeLabel = app.staticTexts["room-code"]
        XCTAssertTrue(codeLabel.waitForExistence(timeout: 90), "방 코드가 나오지 않았습니다")
        let code = codeLabel.label
        XCTAssertEqual(code.count, 6)
        shot("21 방 코드 대기")

        let peer = Peer()
        defer { peer.close() }
        try await peer.send(["type": "join", "code": code])
        _ = try await peer.wait(type: "start")

        // 앱은 연결되자마자 인사를 보낸다
        let hello = try await peer.wait(type: "move", kind: "hello")
        XCTAssertEqual(hello["app"] as? String, "memory_poker")
        try await peer.sendMove(["kind": "hello", "app": "memory_poker"])

        waitForStatus("카드 16장을 외울 준비")
        shot("22 온라인 대기실")

        // 둘 다 준비되면 방장(앱)이 판을 정해 보낸다
        tapButton("준비 완료")
        _ = try await peer.wait(type: "move", kind: "ready")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "상대를 기다리는 중")).firstMatch.waitForExistence(timeout: 5))
        try await peer.sendMove(["kind": "ready", "round": 0])
        let deal = try await peer.wait(type: "move", kind: "deal")
        XCTAssertEqual(deal["seed"] as? String, "3")
        XCTAssertEqual(deal["seconds"] as? Int, 3)
        XCTAssertEqual(deal["round"] as? Int, 0)

        waitForStatus("카드 2장을 고르세요")
        card(9).tap()
        card(10).tap()
        tapButton("선택 완료")
        waitForStatus("상대가 고르는 중…")
        XCTAssertEqual(card(9).label, "뒤집힌 카드, 말 놓음")
        shot("23 상대를 기다리는 중")

        let pick = try await peer.wait(type: "move", kind: "pick")
        XCTAssertEqual(pick["a"] as? Int, 9)
        XCTAssertEqual(pick["b"] as? Int, 10)
        try await peer.sendMove(["kind": "pick", "round": 0, "a": 3, "b": 15])

        waitForStatus("승리!")
        XCTAssertTrue(element("hand-first").label.contains("풀하우스"), element("hand-first").label)
        XCTAssertTrue(element("hand-second").label.contains("투페어"), element("hand-second").label)
        shot("24 온라인 결과")

        // 둘째 판: 상대가 카드 공개 중에 캡처했다고 알려 온다
        tapButton("한 판 더")
        let ready = try await peer.wait(type: "move", kind: "ready")
        XCTAssertEqual(ready["round"] as? Int, 1)
        try await peer.sendMove(["kind": "ready", "round": 1])
        let secondDeal = try await peer.wait(type: "move", kind: "deal")
        XCTAssertEqual(secondDeal["seed"] as? String, "4")
        waitForStatus("카드를 외우세요")
        try await peer.sendMove(["kind": "forfeit", "round": 1])
        waitForStatus("상대의 암기 위반 — 승리!")
        shot("25 상대의 암기 위반")

        tapButton("한 판 더")
        XCTAssertTrue(app.staticTexts["record"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["record"].label.contains("2 : 0"), app.staticTexts["record"].label)

        // 상대가 나가면 알려 주고 로비로 돌아온다
        peer.close()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 45), "상대 퇴장 알림이 뜨지 않았습니다")
        shot("26 상대 퇴장")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        tapButton("새 방 만들기")
    }

    /// 상대가 만든 방에 앱이 코드로 들어간다(참가자). 방장이 보낸 시드대로 같은 카드가 깔려야 한다.
    func test2_GuestJoinsWithCode() async throws {
        let peer = Peer()
        defer { peer.close() }
        try await peer.send(["type": "create"])
        let room = try await peer.wait(type: "room", timeout: 90)
        let code = try XCTUnwrap(room["code"] as? String)

        tapButton("온라인 대전")
        let field = app.textFields["join-code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(code.lowercased())   // 소문자로 쳐도 대문자로 바뀐다
        XCTAssertEqual(field.value as? String, code)
        shot("27 코드 입력")
        tapButton("입장")

        _ = try await peer.wait(type: "start")
        _ = try await peer.wait(type: "move", kind: "hello")
        try await peer.sendMove(["kind": "hello", "app": "memory_poker"])

        waitForStatus("카드 16장을 외울 준비")
        tapButton("준비 완료")
        _ = try await peer.wait(type: "move", kind: "ready")
        try await peer.sendMove(["kind": "ready", "round": 0])
        try await peer.sendMove(["kind": "deal", "round": 0, "seed": "3", "seconds": 5])

        waitForStatus("카드를 외우세요")
        XCTAssertEqual(card(9).label, "스페이드 Q")
        XCTAssertEqual(card(10).label, "클로버 A")
        shot("28 참가자: 방장이 정한 카드")

        // 상대가 먼저 골라도, 내가 고를 때까지는 공개되지 않는다
        try await peer.sendMove(["kind": "pick", "round": 0, "a": 9, "b": 10])
        waitForStatus("카드 2장을 고르세요")
        card(3).tap()
        card(15).tap()
        tapButton("선택 완료")
        let pick = try await peer.wait(type: "move", kind: "pick")
        XCTAssertEqual(pick["a"] as? Int, 3)
        XCTAssertEqual(pick["b"] as? Int, 15)
        waitForStatus("패배…")
        shot("29 참가자 결과")
    }

    func test3_UnknownCodeShowsError() async throws {
        tapButton("온라인 대전")
        let field = app.textFields["join-code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("222222")
        tapButton("입장")
        let error = element("lobby-error")
        XCTAssertTrue(error.waitForExistence(timeout: 90), "오류 문구가 나오지 않았습니다")
        shot("30 없는 방 코드")
    }
}

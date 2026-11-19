import XCTest

/// 시뮬레이터에서 실제로 앱을 눌러 보며 주요 흐름을 확인하고 스크린샷을 남긴다.
/// 스크린샷은 xcresult 첨부로 저장되어 ui-tests 워크플로가 아티팩트로 올린다.
///
/// `-uiTestSeed 3`으로 판을 고정한다. 3번 판은 공유 카드가 A♦ A♥ Q♥이고
/// 9번 칸(Q♠)과 10번 칸(A♣)을 고르면 A 풀하우스 — 이 판의 유일한 최고 조합이다.
/// 다음 판(시드 4)은 공유 카드 2♥ 6♥ K♠, 0번·1번 칸(8♠ Q♠)을 고르면 하이카드.
final class PlaythroughTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        launch(language: "ko", memorizeTime: 3)
    }

    // MARK: - 도우미

    private func launch(language: String, memorizeTime: Int) {
        let locale = language == "ko" ? "ko_KR" : "en_US"
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale,
                               "-uiTestSeed", "3", "-memorizeTime", "\(memorizeTime)"]
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapButton(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = button(containing: text)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "버튼 없음: \(text)", file: file, line: line)
        element.tap()
    }

    private var status: XCUIElement { app.staticTexts["status"] }

    private func card(_ index: Int) -> XCUIElement { app.buttons["card-\(index)"] }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// status 문구가 바뀔 때까지 기다린다.
    private func waitForStatus(_ text: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if status.exists, status.label == text { return }
            usleep(200_000)
        }
        XCTFail("status가 '\(text)'가 되지 않았습니다 (지금: \(status.exists ? status.label : "없음"))", file: file, line: line)
    }

    private func tapCards(_ indices: [Int]) {
        for index in indices {
            XCTAssertTrue(card(index).waitForExistence(timeout: 5))
            card(index).tap()
        }
    }

    // MARK: - 시나리오

    func test1_HomeAndRules() {
        XCTAssertTrue(app.staticTexts["기억 포커"].waitForExistence(timeout: 5))
        shot("01 홈")

        tapButton("규칙과 족보 보기")
        XCTAssertTrue(app.staticTexts["규칙과 족보"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["스트레이트 플러시"].exists)
        shot("02 규칙과 족보")
        tapButton("닫기")
        XCTAssertTrue(button(containing: "연습").waitForExistence(timeout: 5))
    }

    /// 연습: 타이머가 끝나면 카드가 덮이고, 최고의 조합을 고르면 '완벽'.
    func test2_Practice() {
        tapButton("연습")
        waitForStatus("카드 16장을 외울 준비")
        XCTAssertEqual(card(9).label, "뒤집힌 카드")
        XCTAssertFalse(element("community-0").exists, "공유 카드는 아직 공개되면 안 됩니다")
        shot("03 연습 시작 전")

        tapButton("카드 공개")
        waitForStatus("카드를 외우세요")
        XCTAssertEqual(card(9).label, "스페이드 Q")
        XCTAssertEqual(card(10).label, "클로버 A")
        XCTAssertFalse(element("community-0").exists)
        shot("04 암기 중")

        // 3초 타이머가 끝나면 저절로 고르기 단계로 넘어간다
        waitForStatus("카드 2장을 고르세요")
        XCTAssertEqual(card(9).label, "뒤집힌 카드")
        XCTAssertEqual(element("community-0").label, "다이아몬드 A")
        shot("05 공유 카드 공개")

        XCTAssertFalse(button(containing: "선택 완료").isEnabled)
        tapCards([9, 10])
        XCTAssertEqual(card(9).label, "뒤집힌 카드, 말 놓음")
        XCTAssertTrue(button(containing: "선택 완료").isEnabled)
        shot("06 말 2개 배치")

        tapButton("선택 완료")
        waitForStatus("완벽! 최고의 조합입니다")
        XCTAssertTrue(card(9).label.contains("스페이드 Q"))
        XCTAssertTrue(element("hand-first").label.contains("풀하우스"), element("hand-first").label)
        XCTAssertFalse(element("hand-best").exists, "최고의 조합을 찾았으면 따로 보여 주지 않습니다")
        shot("07 연습 결과: 완벽")

        // 다음 판: 일부러 낮은 조합을 고른다
        tapButton("한 판 더")
        waitForStatus("카드 16장을 외울 준비")
        XCTAssertTrue(app.staticTexts["record"].label.contains("1/1"), app.staticTexts["record"].label)
        tapButton("카드 공개")
        tapButton("다 외웠어요")
        waitForStatus("카드 2장을 고르세요")
        tapCards([0, 1])
        tapButton("선택 완료")
        waitForStatus("아쉬워요, 더 높은 조합이 있었어요")
        XCTAssertTrue(element("hand-first").label.contains("하이카드"), element("hand-first").label)
        XCTAssertTrue(element("hand-best").label.contains("트리플"), element("hand-best").label)
        shot("08 연습 결과: 더 높은 조합이 있었음")
    }

    /// 컴퓨터 대전: 세 번째 칸을 누르면 먼저 놓은 말이 옮겨 가고, 최고의 조합을 고르면 지지 않는다.
    func test3_VsComputerHard() {
        tapButton("어려움")
        tapButton("컴퓨터 대전")
        tapButton("카드 공개")
        tapButton("다 외웠어요")
        waitForStatus("카드 2장을 고르세요")

        tapCards([0, 9, 10])
        XCTAssertEqual(card(0).label, "뒤집힌 카드", "먼저 놓은 말은 치워져야 합니다")
        XCTAssertEqual(card(9).label, "뒤집힌 카드, 말 놓음")
        XCTAssertEqual(card(10).label, "뒤집힌 카드, 말 놓음")

        // 놓은 말을 다시 누르면 치워진다
        tapCards([10])
        XCTAssertEqual(card(10).label, "뒤집힌 카드")
        XCTAssertFalse(button(containing: "선택 완료").isEnabled)
        tapCards([10])
        shot("09 컴퓨터 대전: 고르는 중")

        tapButton("선택 완료")
        XCTAssertTrue(button(containing: "한 판 더").waitForExistence(timeout: 5))
        XCTAssertTrue(element("hand-second").exists, "컴퓨터의 조합이 보여야 합니다")
        XCTAssertTrue(["승리!", "무승부"].contains(status.label), "최고의 조합으로 졌습니다: \(status.label)")
        shot("10 컴퓨터 대전 결과: \(status.label)")

        tapButton("한 판 더")
        waitForStatus("카드 16장을 외울 준비")
        XCTAssertTrue(app.staticTexts["record"].waitForExistence(timeout: 5))
        shot("11 전적: \(app.staticTexts["record"].label)")
    }

    /// 함께 하기: 기기를 넘길 때 앞사람의 말이 보이지 않아야 한다.
    func test4_TwoPlayer() {
        tapButton("함께 하기")
        tapButton("카드 공개")
        tapButton("다 외웠어요")
        waitForStatus("플레이어 1이 고를 차례")

        tapCards([3, 15])   // K♣ K♠ → 투페어
        tapButton("선택 완료")
        XCTAssertTrue(app.staticTexts["플레이어 2 차례"].waitForExistence(timeout: 5))
        shot("12 기기 넘기기")

        tapButton("준비됐어요")
        waitForStatus("플레이어 2가 고를 차례")
        XCTAssertEqual(card(3).label, "뒤집힌 카드", "앞사람이 놓은 말이 보이면 안 됩니다")
        XCTAssertEqual(card(15).label, "뒤집힌 카드")
        tapCards([9, 10])   // Q♠ A♣ → 풀하우스
        tapButton("선택 완료")

        waitForStatus("플레이어 2 승리!")
        XCTAssertTrue(element("hand-first").label.contains("투페어"), element("hand-first").label)
        XCTAssertTrue(element("hand-second").label.contains("풀하우스"), element("hand-second").label)
        shot("13 함께 하기 결과")

        // 다음 판은 플레이어 2가 먼저 고른다
        tapButton("한 판 더")
        waitForStatus("카드 16장을 외울 준비")
        XCTAssertTrue(app.staticTexts["record"].label.contains("0 : 1"), app.staticTexts["record"].label)
        tapButton("카드 공개")
        tapButton("다 외웠어요")
        waitForStatus("플레이어 2가 고를 차례")
        shot("14 둘째 판: 플레이어 2 먼저")
    }

    func test5_English() {
        app.terminate()
        launch(language: "en", memorizeTime: 3)
        XCTAssertTrue(app.staticTexts["Memory Poker"].waitForExistence(timeout: 5))
        shot("15 English home")

        tapButton("Rules and hand rankings")
        XCTAssertTrue(app.staticTexts["Full House"].waitForExistence(timeout: 5))
        shot("16 English rules")
        tapButton("Close")

        tapButton("vs Computer")
        tapButton("Reveal cards")
        waitForStatus("Memorize the cards")
        XCTAssertEqual(card(9).label, "Spades Q")
        tapButton("I've got it")
        waitForStatus("Pick 2 cards")
        tapCards([9, 10])
        tapButton("Confirm")
        XCTAssertTrue(button(containing: "Play again").waitForExistence(timeout: 5))
        XCTAssertTrue(element("hand-first").label.contains("Full House"), element("hand-first").label)
        shot("17 English result: \(status.label)")
    }
}

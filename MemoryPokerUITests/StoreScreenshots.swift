import XCTest

/// App Store 제출용 스크린샷. 시드로 고정한 판에서 정해진 칸을 눌러 매번 같은 화면을 만든다.
/// store-screenshots 워크플로가 6.9" 시뮬레이터에서 이 클래스만 실행한다.
/// 언어는 TEST_RUNNER_STORE_LANG(ko/en)으로 고른다.
///
/// 시드 3: 공유 카드 A♦ A♥ Q♥, 9번(Q♠)·10번(A♣)이 A 풀하우스, 3번(K♣)·15번(K♠)은 투페어.
final class StoreScreenshots: XCTestCase {

    private var app: XCUIApplication!
    private let isEnglish = ProcessInfo.processInfo.environment["STORE_LANG"] == "en"

    /// 화면 문구 (한국어, 영어)
    private func t(_ ko: String, _ en: String) -> String { isEnglish ? en : ko }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        let language = isEnglish ? ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] : ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchArguments = language + ["-uiTestSeed", "3", "-memorizeTime", "20", "-botLevel", "hard"]
        app.launch()
    }

    private func shot(_ name: String) {
        sleep(1) // 카드 뒤집기 애니메이션이 끝난 뒤 찍는다
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapButton(_ text: String) {
        let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "버튼 없음: \(text)")
        element.tap()
    }

    private func tapCards(_ indices: [Int]) {
        for index in indices {
            let card = app.buttons["card-\(index)"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            card.tap()
        }
    }

    func test1_Home() {
        XCTAssertTrue(app.staticTexts[t("기억 포커", "Memory Poker")].waitForExistence(timeout: 5))
        shot("1 홈")
    }

    func test2_Memorize() {
        tapButton(t("컴퓨터 대전", "vs Computer"))
        tapButton(t("카드 공개", "Reveal cards"))
        shot("2 16장 외우기")
    }

    func test3_Select() {
        tapButton(t("컴퓨터 대전", "vs Computer"))
        tapButton(t("카드 공개", "Reveal cards"))
        tapButton(t("다 외웠어요", "I've got it"))
        tapCards([9, 10])
        shot("3 말 놓기")
    }

    func test4_Reveal() {
        tapButton(t("함께 하기", "Two Players"))
        tapButton(t("카드 공개", "Reveal cards"))
        tapButton(t("다 외웠어요", "I've got it"))
        tapCards([3, 15])
        tapButton(t("선택 완료", "Confirm"))
        tapButton(t("준비됐어요", "I'm ready"))
        tapCards([9, 10])
        tapButton(t("선택 완료", "Confirm"))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", t("한 판 더", "Play again"))).firstMatch.waitForExistence(timeout: 5))
        shot("4 공개와 승패")
    }

    func test5_Rules() {
        tapButton(t("규칙과 족보 보기", "Rules and hand rankings"))
        XCTAssertTrue(app.staticTexts[t("규칙과 족보", "Rules & Rankings")].waitForExistence(timeout: 5))
        shot("5 규칙과 족보")
    }
}

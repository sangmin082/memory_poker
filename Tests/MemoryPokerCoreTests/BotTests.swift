import XCTest
@testable import MemoryPokerCore

final class BotTests: XCTestCase {

    func testPerfectMemoryPicksTheBestHand() {
        var rng = SplitMix64(seed: 5)
        for _ in 0..<100 {
            let deal = Deal.random(using: &rng)
            let memory = deal.board.map { Bot.Memory.exact($0) }
            let pick = Bot.choosePick(deal: deal, memory: memory, using: &rng)
            XCTAssertEqual(deal.value(for: pick), deal.best().value)
        }
    }

    func testPickIsAlwaysTwoDifferentCells() {
        var rng = SplitMix64(seed: 11)
        for level in BotLevel.allCases {
            for _ in 0..<300 {
                let deal = Deal.random(using: &rng)
                let pick = Bot.choosePick(deal: deal, level: level, using: &rng)
                XCTAssertNotEqual(pick.low, pick.high)
                XCTAssertTrue((0..<16).contains(pick.low) && (0..<16).contains(pick.high))
            }
        }
    }

    func testForgottenEverythingStillPicks() {
        var rng = SplitMix64(seed: 3)
        let deal = Deal.random(using: &rng)
        let blank = [Bot.Memory](repeating: .forgotten, count: 16)
        let pick = Bot.choosePick(deal: deal, memory: blank, using: &rng)
        XCTAssertNotEqual(pick.low, pick.high)

        // 한 장만 기억하면 그 카드는 반드시 고른다
        var one = blank
        one[6] = .exact(deal.board[6])
        XCTAssertTrue(Bot.choosePick(deal: deal, memory: one, using: &rng).contains(6))
    }

    func testOnlyRememberedCellsAreChosen() {
        var rng = SplitMix64(seed: 21)
        for _ in 0..<100 {
            let deal = Deal.random(using: &rng)
            var memory = [Bot.Memory](repeating: .forgotten, count: 16)
            for index in [1, 4, 7, 10, 13] { memory[index] = .exact(deal.board[index]) }
            let pick = Bot.choosePick(deal: deal, memory: memory, using: &rng)
            XCTAssertTrue([1, 4, 7, 10, 13].contains(pick.low) && [1, 4, 7, 10, 13].contains(pick.high))
        }
    }

    func testMisrememberedCardIsCloseButDifferent() {
        var rng = SplitMix64(seed: 8)
        for card in Card.deck {
            for _ in 0..<20 {
                let wrong = Bot.misremember(card, using: &rng)
                XCTAssertNotEqual(wrong, card)
                let sameRank = wrong.rank == card.rank
                let sameSuit = wrong.suit == card.suit
                XCTAssertTrue(sameRank != sameSuit, "문양이나 숫자 중 하나만 달라야 한다")
                XCTAssertLessThanOrEqual(abs(wrong.rank - card.rank), 1)
            }
        }
    }

    func testSameSeedGivesSamePick() {
        let deal = Deal.random()
        for level in BotLevel.allCases {
            var a = SplitMix64(seed: 77)
            var b = SplitMix64(seed: 77)
            XCTAssertEqual(Bot.choosePick(deal: deal, level: level, using: &a),
                           Bot.choosePick(deal: deal, level: level, using: &b))
        }
    }

    /// 난이도가 높을수록 최고의 조합을 더 자주 찾아야 한다.
    func testHarderLevelsFindTheBestHandMoreOften() {
        func bestRate(_ level: BotLevel) -> Double {
            var rng = SplitMix64(seed: 2026)
            let rounds = 600
            var hits = 0
            for _ in 0..<rounds {
                let deal = Deal.random(using: &rng)
                let pick = Bot.choosePick(deal: deal, level: level, using: &rng)
                if deal.value(for: pick) == deal.best().value { hits += 1 }
            }
            return Double(hits) / Double(rounds)
        }
        let easy = bestRate(.easy), normal = bestRate(.normal), hard = bestRate(.hard)
        print("최고 조합을 찾는 비율 — 쉬움 \(easy), 보통 \(normal), 어려움 \(hard)")
        XCTAssertLessThan(easy, normal)
        XCTAssertLessThan(normal, hard)
        XCTAssertLessThan(easy, 0.45)
        XCTAssertGreaterThan(hard, 0.70)
        XCTAssertLessThan(hard, 0.98, "어려움도 가끔은 틀려야 이길 수 있다")
    }
}

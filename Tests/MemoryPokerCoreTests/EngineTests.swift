import XCTest
@testable import MemoryPokerCore

final class EngineTests: XCTestCase {

    private func hand(_ text: String) -> [Card] {
        text.split(separator: " ").map { Card(String($0))! }
    }

    private func value(_ text: String) -> HandValue {
        HandEvaluator.evaluate(hand(text))
    }

    // MARK: - 카드

    func testDeckHas52UniqueCards() {
        XCTAssertEqual(Card.deck.count, 52)
        XCTAssertEqual(Set(Card.deck).count, 52)
    }

    func testCardParsing() {
        XCTAssertEqual(Card("AS"), Card(rank: 14, suit: .spades))
        XCTAssertEqual(Card("10h"), Card(rank: 10, suit: .hearts))
        XCTAssertEqual(Card("TD"), Card(rank: 10, suit: .diamonds))
        XCTAssertEqual(Card("2C"), Card(rank: 2, suit: .clubs))
        XCTAssertNil(Card("1S"))
        XCTAssertNil(Card("AX"))
        XCTAssertEqual(Card("QH")?.description, "Q♥")
    }

    // MARK: - 족보 판정

    func testCategories() {
        XCTAssertEqual(value("AS KS QS JS TS").category, .straightFlush)
        XCTAssertEqual(value("5H 4H 3H 2H AH").category, .straightFlush)
        XCTAssertEqual(value("9S 9H 9D 9C 2S").category, .fourOfAKind)
        XCTAssertEqual(value("9S 9H 9D 2C 2S").category, .fullHouse)
        XCTAssertEqual(value("AS 9S 7S 4S 2S").category, .flush)
        XCTAssertEqual(value("9S 8H 7D 6C 5S").category, .straight)
        XCTAssertEqual(value("AS 2H 3D 4C 5S").category, .straight)
        XCTAssertEqual(value("9S 9H 9D KC 2S").category, .threeOfAKind)
        XCTAssertEqual(value("9S 9H KD KC 2S").category, .twoPair)
        XCTAssertEqual(value("9S 9H AD KC 2S").category, .onePair)
        XCTAssertEqual(value("AS JH 9D 4C 2S").category, .highCard)
    }

    func testAroundTheCornerIsNotAStraight() {
        XCTAssertEqual(value("KS AH 2D 3C 4S").category, .highCard)
        XCTAssertEqual(value("QS KH AD 2C 3S").category, .highCard)
    }

    func testCategoryOrder() {
        let ordered = [
            value("AS JH 9D 4C 2S"),   // 하이카드
            value("2S 2H 5D 4C 3S"),   // 원페어
            value("3S 3H 2D 2C 4S"),   // 투페어
            value("2S 2H 2D 4C 3S"),   // 트리플
            value("AS 2H 3D 4C 5S"),   // 스트레이트
            value("7S 5S 4S 3S 2S"),   // 플러시
            value("2S 2H 2D 3C 3S"),   // 풀하우스
            value("2S 2H 2D 2C 3S"),   // 포카드
            value("5H 4H 3H 2H AH"),   // 스트레이트 플러시
        ]
        for index in ordered.indices.dropLast() {
            XCTAssertLessThan(ordered[index], ordered[index + 1], "\(index)번째 족보 순서")
        }
        XCTAssertEqual(ordered.map(\.category), HandCategory.allCases)
    }

    // MARK: - 같은 족보끼리 비교

    func testHigherRankWinsWithinCategory() {
        XCTAssertGreaterThan(value("KS KH 2D 3C 4S"), value("QS QH AD KC JS"))          // 페어 숫자가 먼저
        XCTAssertGreaterThan(value("AS AH 2D 2C 3S"), value("KS KH QD QC AS"))          // 높은 페어가 먼저
        XCTAssertGreaterThan(value("KS KH QD QC 2S"), value("KD KC JD JC AS"))          // 낮은 페어
        XCTAssertGreaterThan(value("3S 3H 3D 2C 2S"), value("2H 2D 2C AS AH"))          // 풀하우스는 트리플 숫자
        XCTAssertGreaterThan(value("9S 8H 7D 6C 5S"), value("8S 7H 6D 5C 4S"))
        XCTAssertGreaterThan(value("6S 5H 4D 3C 2S"), value("AS 2H 3D 4C 5S"))          // A-5가 가장 낮은 스트레이트
        XCTAssertGreaterThan(value("AS KS QS JS 9S"), value("AH KH QH JH 8H"))          // 플러시는 높은 카드부터
    }

    func testKickersBreakTies() {
        XCTAssertGreaterThan(value("KS KH AD 3C 2S"), value("KD KC QD JC TS"))
        XCTAssertGreaterThan(value("KS KH AD 4C 2S"), value("KD KC AH 3C 2D"))
        XCTAssertGreaterThan(value("KS KH QD QC 3S"), value("KD KC QS QH 2S"))
        XCTAssertGreaterThan(value("AS JH 9D 4C 3S"), value("AD JS 9H 4D 2S"))
        XCTAssertGreaterThan(value("9S 9H 9D 9C 3S"), value("9S 9H 9D 9C 2S"))
    }

    func testSuitsAreNotCompared() {
        XCTAssertEqual(value("AS KS QS JS 9S"), value("AH KH QH JH 9H"))
        XCTAssertEqual(value("KS KH AD 4C 2S"), value("KD KC AH 4S 2D"))
        XCTAssertEqual(value("9S 8H 7D 6C 5S"), value("9H 8D 7C 6S 5H"))
    }

    func testCoreCards() {
        XCTAssertEqual(Set(HandEvaluator.coreCards(hand("9S 9H AD KC 2S"))), Set(hand("9S 9H")))
        XCTAssertEqual(Set(HandEvaluator.coreCards(hand("9S 9H KD KC 2S"))), Set(hand("9S 9H KD KC")))
        XCTAssertEqual(Set(HandEvaluator.coreCards(hand("9S 9H 9D KC 2S"))), Set(hand("9S 9H 9D")))
        XCTAssertEqual(Set(HandEvaluator.coreCards(hand("9S 9H 9D 9C 2S"))), Set(hand("9S 9H 9D 9C")))
        XCTAssertEqual(HandEvaluator.coreCards(hand("AS JH 9D 4C 2S")), hand("AS"))
        XCTAssertEqual(HandEvaluator.coreCards(hand("9S 8H 7D 6C 5S")).count, 5)
        XCTAssertEqual(HandEvaluator.coreCards(hand("9S 9H 9D 2C 2S")).count, 5)
    }

    // MARK: - 판

    func testRandomDealIsValid() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<200 {
            let deal = Deal.random(using: &rng)
            XCTAssertEqual(deal.board.count, 16)
            XCTAssertEqual(deal.community.count, 3)
            XCTAssertEqual(Set(deal.board + deal.community).count, 19)
        }
    }

    func testSameSeedGivesSameDeal() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)
        var c = SplitMix64(seed: 43)
        let dealA = Deal.random(using: &a)
        XCTAssertEqual(dealA, Deal.random(using: &b))
        XCTAssertNotEqual(dealA, Deal.random(using: &c))
    }

    func testShuffleCoversTheDeck() {
        var rng = SplitMix64(seed: 7)
        var seenOnBoard = Set<Card>()
        for _ in 0..<200 { seenOnBoard.formUnion(Deal.random(using: &rng).board) }
        XCTAssertEqual(seenOnBoard.count, 52)
    }

    func testAllPicks() {
        XCTAssertEqual(Deal.allPicks.count, 120)
        XCTAssertEqual(Set(Deal.allPicks).count, 120)
        XCTAssertEqual(Pick(5, 2), Pick(2, 5))
        XCTAssertEqual(Pick(5, 2).indices, [2, 5])
    }

    private func sampleDeal() -> Deal {
        // 공유 카드 K♠ K♥ 7♦ — 판에 K♦(3번)와 7♣(9번), 7♠(12번)이 있다.
        let board = hand("2S 3H 5D KD 9C JS 4H 8D QC 7C 6H 2D 7S TC 3C AD")
        return Deal(board: board, community: hand("KS KH 7D"))
    }

    func testBestPickFindsFullHouse() {
        let deal = sampleDeal()
        let best = deal.best()
        XCTAssertEqual(best.value.category, .fullHouse)
        // K 풀하우스(K K K 7 7): K♦ + 7 한 장
        XCTAssertEqual(Set(best.picks), [Pick(3, 9), Pick(3, 12)])
        XCTAssertEqual(best.value, HandValue(category: .fullHouse, tiebreak: [13, 7]))
        // 7 두 장을 고르면 7 풀하우스 — 같은 족보지만 K 풀하우스보다 낮다
        XCTAssertEqual(deal.value(for: Pick(9, 12)), HandValue(category: .fullHouse, tiebreak: [7, 13]))
        XCTAssertLessThan(deal.value(for: Pick(9, 12)), best.value)
    }

    func testBestIsNeverBeaten() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<100 {
            let deal = Deal.random(using: &rng)
            let best = deal.best()
            XCTAssertFalse(best.picks.isEmpty)
            for pick in Deal.allPicks {
                XCTAssertLessThanOrEqual(deal.value(for: pick), best.value)
                XCTAssertEqual(best.picks.contains(pick), deal.value(for: pick) == best.value)
            }
        }
    }

    func testOutcome() {
        let deal = sampleDeal()
        XCTAssertEqual(deal.outcome(first: Pick(3, 9), second: Pick(0, 1)), .firstWins)
        XCTAssertEqual(deal.outcome(first: Pick(0, 1), second: Pick(3, 9)), .secondWins)
        XCTAssertEqual(deal.outcome(first: Pick(3, 9), second: Pick(3, 12)), .draw)   // 문양만 다른 같은 조합
        XCTAssertEqual(deal.outcome(first: Pick(3, 9), second: Pick(3, 9)), .draw)    // 같은 카드를 골라도 된다
    }
}

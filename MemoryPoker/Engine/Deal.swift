import Foundation

/// 게임판 16칸 중 고른 2칸. 순서는 의미가 없다.
public struct Pick: Hashable, Sendable {
    public let low: Int
    public let high: Int

    public init(_ a: Int, _ b: Int) {
        precondition(a != b, "서로 다른 두 칸을 골라야 한다")
        low = min(a, b)
        high = max(a, b)
    }

    public var indices: [Int] { [low, high] }

    public func contains(_ index: Int) -> Bool { index == low || index == high }
}

public enum Outcome: Hashable, Sendable {
    case firstWins, secondWins, draw
}

/// 한 판에 깔리는 카드: 외워야 하는 16장과 공유 카드 3장.
public struct Deal: Hashable, Sendable {
    public static let boardSize = 16
    public static let communitySize = 3

    public let board: [Card]
    public let community: [Card]

    public init(board: [Card], community: [Card]) {
        precondition(board.count == Deal.boardSize && community.count == Deal.communitySize)
        precondition(Set(board + community).count == Deal.boardSize + Deal.communitySize, "같은 카드가 두 번 나올 수 없다")
        self.board = board
        self.community = community
    }

    /// 52장을 섞어 앞의 16장을 판에, 다음 3장을 공유 카드로 쓴다.
    /// 표준 라이브러리의 shuffle 대신 직접 섞어서, 같은 시드면 어느 플랫폼에서나 같은 판이 나오게 한다.
    public static func random<G: RandomNumberGenerator>(using rng: inout G) -> Deal {
        var deck = Card.deck
        for i in stride(from: deck.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            deck.swapAt(i, j)
        }
        return Deal(board: Array(deck[0..<boardSize]),
                    community: Array(deck[boardSize..<(boardSize + communitySize)]))
    }

    public static func random() -> Deal {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }

    /// 고른 2장 + 공유 카드 3장
    public func cards(for pick: Pick) -> [Card] {
        [board[pick.low], board[pick.high]] + community
    }

    public func value(for pick: Pick) -> HandValue {
        HandEvaluator.evaluate(cards(for: pick))
    }

    /// 16칸에서 2칸을 고르는 120가지 전부
    public static let allPicks: [Pick] = {
        var picks: [Pick] = []
        for a in 0..<boardSize {
            for b in (a + 1)..<boardSize {
                picks.append(Pick(a, b))
            }
        }
        return picks
    }()

    /// 이 판에서 만들 수 있는 가장 강한 조합과, 그 조합이 되는 모든 선택.
    public func best() -> (value: HandValue, picks: [Pick]) {
        var bestValue = value(for: Deal.allPicks[0])
        var bestPicks: [Pick] = []
        for pick in Deal.allPicks {
            let candidate = value(for: pick)
            if candidate > bestValue {
                bestValue = candidate
                bestPicks = [pick]
            } else if candidate == bestValue {
                bestPicks.append(pick)
            }
        }
        return (bestValue, bestPicks)
    }

    public func outcome(first: Pick, second: Pick) -> Outcome {
        let a = value(for: first)
        let b = value(for: second)
        if a > b { return .firstWins }
        if a < b { return .secondWins }
        return .draw
    }
}

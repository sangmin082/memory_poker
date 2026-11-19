import Foundation

public enum BotLevel: String, CaseIterable, Hashable, Sendable {
    case easy, normal, hard

    /// 카드 한 장을 (정확히 기억할 확률, 헷갈려서 기억할 확률). 나머지는 아예 잊는다.
    var recall: (exact: Double, fuzzy: Double) {
        switch self {
        case .easy: return (0.45, 0.20)
        case .normal: return (0.70, 0.15)
        case .hard: return (0.92, 0.05)
        }
    }
}

/// 컴퓨터 상대. 사람처럼 16장을 '불완전하게' 외운 뒤, 자기가 기억하는 대로 가장 강한 2장을 고른다.
/// 수읽기는 완벽하고(120가지를 전부 따진다) 난이도는 기억력으로만 갈린다.
public enum Bot {

    public enum Memory: Hashable, Sendable {
        /// 정확히 기억함
        case exact(Card)
        /// 헷갈림: 문양이나 숫자를 살짝 다르게 기억함
        case fuzzy(Card)
        /// 기억나지 않음
        case forgotten

        public var believed: Card? {
            switch self {
            case .exact(let card), .fuzzy(let card): return card
            case .forgotten: return nil
            }
        }
    }

    /// 판의 16장을 난이도에 맞는 기억력으로 외운다.
    public static func memorize<G: RandomNumberGenerator>(
        _ deal: Deal, level: BotLevel, using rng: inout G
    ) -> [Memory] {
        let recall = level.recall
        return deal.board.map { card in
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < recall.exact { return .exact(card) }
            if roll < recall.exact + recall.fuzzy { return .fuzzy(misremember(card, using: &rng)) }
            return .forgotten
        }
    }

    /// 문양을 다른 것으로, 또는 숫자를 하나 위아래로 잘못 기억한다.
    static func misremember<G: RandomNumberGenerator>(_ card: Card, using rng: inout G) -> Card {
        if Bool.random(using: &rng) {
            let others = Suit.allCases.filter { $0 != card.suit }
            return Card(rank: card.rank, suit: others.randomElement(using: &rng) ?? card.suit)
        }
        var rank = card.rank + (Bool.random(using: &rng) ? 1 : -1)
        if rank > 14 { rank = 13 }
        if rank < 2 { rank = 3 }
        return Card(rank: rank, suit: card.suit)
    }

    /// 기억을 바탕으로 2칸을 고른다. 기억나는 칸이 2칸이 안 되면 모르는 칸을 찍는다.
    public static func choosePick<G: RandomNumberGenerator>(
        deal: Deal, memory: [Memory], using rng: inout G
    ) -> Pick {
        precondition(memory.count == Deal.boardSize)
        let known = memory.indices.filter { memory[$0].believed != nil }
        let unknown = memory.indices.filter { memory[$0].believed == nil }.shuffled(using: &rng)

        if known.count < 2 {
            let chosen = known + unknown.prefix(2 - known.count)
            return Pick(chosen[0], chosen[1])
        }

        var bestValue: HandValue?
        var bestPicks: [Pick] = []
        for (offset, a) in known.enumerated() {
            for b in known[(offset + 1)...] {
                guard let cardA = memory[a].believed, let cardB = memory[b].believed else { continue }
                let value = HandEvaluator.evaluate([cardA, cardB] + deal.community)
                if bestValue == nil || value > bestValue! {
                    bestValue = value
                    bestPicks = [Pick(a, b)]
                } else if value == bestValue {
                    bestPicks.append(Pick(a, b))
                }
            }
        }
        return bestPicks.randomElement(using: &rng) ?? Pick(known[0], known[1])
    }

    public static func choosePick<G: RandomNumberGenerator>(
        deal: Deal, level: BotLevel, using rng: inout G
    ) -> Pick {
        let memory = memorize(deal, level: level, using: &rng)
        return choosePick(deal: deal, memory: memory, using: &rng)
    }
}

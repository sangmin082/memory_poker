import Foundation

/// 족보. 뒤에 있을수록 강하다.
public enum HandCategory: Int, CaseIterable, Comparable, Hashable, Sendable {
    case highCard
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    public static func < (lhs: HandCategory, rhs: HandCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 5장 조합의 세기. 족보가 같으면 tiebreak를 앞에서부터 비교한다.
/// tiebreak는 "족보를 이루는 숫자 → 나머지 카드(키커)" 순서이고, 문양은 들어가지 않는다.
public struct HandValue: Comparable, Hashable, Sendable {
    public let category: HandCategory
    public let tiebreak: [Int]

    public init(category: HandCategory, tiebreak: [Int]) {
        self.category = category
        self.tiebreak = tiebreak
    }

    public static func < (lhs: HandValue, rhs: HandValue) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        return lhs.tiebreak.lexicographicallyPrecedes(rhs.tiebreak)
    }
}

public enum HandEvaluator {

    /// 5장의 족보를 판정한다.
    public static func evaluate(_ cards: [Card]) -> HandValue {
        precondition(cards.count == 5, "조합은 정확히 5장")
        let ranks = cards.map(\.rank).sorted(by: >)
        let groups = rankGroups(ranks)
        let groupRanks = groups.map(\.rank)
        let shape = groups.map(\.count)

        let isFlush = Set(cards.map(\.suit)).count == 1
        let straightTop = straightHigh(ranks)

        if let top = straightTop, isFlush {
            return HandValue(category: .straightFlush, tiebreak: [top])
        }
        if shape[0] >= 4 {
            return HandValue(category: .fourOfAKind, tiebreak: groupRanks)
        }
        if shape[0] == 3, shape.count > 1, shape[1] >= 2 {
            return HandValue(category: .fullHouse, tiebreak: groupRanks)
        }
        if isFlush {
            return HandValue(category: .flush, tiebreak: ranks)
        }
        if let top = straightTop {
            return HandValue(category: .straight, tiebreak: [top])
        }
        if shape[0] == 3 {
            return HandValue(category: .threeOfAKind, tiebreak: groupRanks)
        }
        if shape[0] == 2, shape.count > 1, shape[1] == 2 {
            return HandValue(category: .twoPair, tiebreak: groupRanks)
        }
        if shape[0] == 2 {
            return HandValue(category: .onePair, tiebreak: groupRanks)
        }
        return HandValue(category: .highCard, tiebreak: ranks)
    }

    /// 5장 중 족보를 이루는 카드 (원페어면 그 2장, 하이카드면 가장 높은 1장, 스트레이트·플러시·풀하우스면 5장 전부).
    public static func coreCards(_ cards: [Card]) -> [Card] {
        let value = evaluate(cards)
        let groupRanks = rankGroups(cards.map(\.rank).sorted(by: >)).map(\.rank)
        switch value.category {
        case .straightFlush, .flush, .straight, .fullHouse:
            return cards
        case .fourOfAKind, .threeOfAKind, .onePair:
            return cards.filter { $0.rank == groupRanks[0] }
        case .twoPair:
            return cards.filter { $0.rank == groupRanks[0] || $0.rank == groupRanks[1] }
        case .highCard:
            let top = cards.max { $0.rank < $1.rank }
            return top.map { [$0] } ?? []
        }
    }

    /// 같은 숫자끼리 묶어 (장수 많은 순 → 숫자 높은 순)으로 정렬한다.
    private static func rankGroups(_ ranks: [Int]) -> [(rank: Int, count: Int)] {
        var counts: [Int: Int] = [:]
        for rank in ranks { counts[rank, default: 0] += 1 }
        return counts
            .map { (rank: $0.key, count: $0.value) }
            .sorted { ($0.count, $0.rank) > ($1.count, $1.rank) }
    }

    /// 스트레이트면 가장 높은 숫자를 돌려준다. A-2-3-4-5는 5가 가장 높은 스트레이트로 본다.
    private static func straightHigh(_ sortedDescending: [Int]) -> Int? {
        guard Set(sortedDescending).count == 5 else { return nil }
        if sortedDescending[0] - sortedDescending[4] == 4 { return sortedDescending[0] }
        if sortedDescending == [14, 5, 4, 3, 2] { return 5 }
        return nil
    }
}

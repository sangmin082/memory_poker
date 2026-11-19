import Foundation

/// 문양. 족보 비교에서 문양의 높낮이는 따지지 않는다(플러시 여부에만 쓴다).
public enum Suit: Int, CaseIterable, Hashable, Sendable {
    case spades, hearts, diamonds, clubs

    public var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    public var isRed: Bool { self == .hearts || self == .diamonds }
}

/// 플레잉 카드 한 장. rank는 2...14 (J=11, Q=12, K=13, A=14).
public struct Card: Hashable, Sendable, CustomStringConvertible {
    public let rank: Int
    public let suit: Suit

    public init(rank: Int, suit: Suit) {
        precondition((2...14).contains(rank), "rank는 2...14")
        self.rank = rank
        self.suit = suit
    }

    /// "AS", "10H", "TD", "2c" 같은 표기를 읽는다 (테스트·예시용).
    public init?(_ text: String) {
        let upper = text.uppercased()
        guard let suitChar = upper.last else { return nil }
        let suit: Suit
        switch suitChar {
        case "S": suit = .spades
        case "H": suit = .hearts
        case "D": suit = .diamonds
        case "C": suit = .clubs
        default: return nil
        }
        let rank: Int
        switch String(upper.dropLast()) {
        case "A": rank = 14
        case "K": rank = 13
        case "Q": rank = 12
        case "J": rank = 11
        case "T", "10": rank = 10
        case let digits:
            guard let value = Int(digits), (2...9).contains(value) else { return nil }
            rank = value
        }
        self.init(rank: rank, suit: suit)
    }

    public static func label(forRank rank: Int) -> String {
        switch rank {
        case 14: return "A"
        case 13: return "K"
        case 12: return "Q"
        case 11: return "J"
        default: return String(rank)
        }
    }

    public var rankLabel: String { Card.label(forRank: rank) }

    public var description: String { rankLabel + suit.symbol }

    /// 조커 없는 52장
    public static let deck: [Card] = Suit.allCases.flatMap { suit in
        (2...14).map { Card(rank: $0, suit: suit) }
    }
}

/// 시드로 재현할 수 있는 난수 생성기 (테스트·스크린샷에서 같은 판을 만들기 위해 쓴다).
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

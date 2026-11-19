import SwiftUI

/// 앱 전역 팔레트 — 페이퍼 & 잉크, 버밀리언 악센트.
/// 다크모드 분기 없이 하나의 톤으로 고정한 보드게임 룩.
enum Theme {
    static let paper = Color(red: 0.957, green: 0.945, blue: 0.902)     // 배경
    static let ink = Color(red: 0.106, green: 0.118, blue: 0.149)       // 본문 / 검은 문양 / 카드 뒷면
    static let inkSoft = Color(red: 0.106, green: 0.118, blue: 0.149).opacity(0.55)
    static let accent = Color(red: 0.776, green: 0.263, blue: 0.169)    // 버밀리언: 붉은 문양 · 내 말
    static let hairline = Color(red: 0.106, green: 0.118, blue: 0.149).opacity(0.18)
    static let sea = Color(red: 0.180, green: 0.400, blue: 0.443)       // 상대 말
    static let gold = Color(red: 0.80, green: 0.62, blue: 0.20)         // 최고의 조합 표시
    static let cardFace = Color(red: 0.996, green: 0.990, blue: 0.972)  // 카드 앞면

    static func color(for seat: Seat) -> Color {
        seat == .first ? accent : sea
    }

    static func color(for suit: Suit) -> Color {
        suit.isRed ? accent : ink
    }
}

/// 본문 버튼: 잉크 테두리의 플랫 버튼
struct InkButtonStyle: ButtonStyle {
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? Theme.paper : Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(filled ? Theme.ink : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink, lineWidth: 1.5))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 엔진 타입의 화면 표기 (엔진은 UI·현지화와 분리되어 있음)
extension BotLevel {
    var label: LocalizedStringKey {
        switch self {
        case .easy: return "쉬움"
        case .normal: return "보통"
        case .hard: return "어려움"
        }
    }
}

extension HandCategory {
    var label: LocalizedStringKey {
        switch self {
        case .highCard: return "하이카드"
        case .onePair: return "원페어"
        case .twoPair: return "투페어"
        case .threeOfAKind: return "트리플"
        case .straight: return "스트레이트"
        case .flush: return "플러시"
        case .fullHouse: return "풀하우스"
        case .fourOfAKind: return "포카드"
        case .straightFlush: return "스트레이트 플러시"
        }
    }
}

extension Suit {
    /// VoiceOver용 이름
    var spokenName: String {
        switch self {
        case .spades: return String(localized: "스페이드")
        case .hearts: return String(localized: "하트")
        case .diamonds: return String(localized: "다이아몬드")
        case .clubs: return String(localized: "클로버")
        }
    }

    /// 이모지가 아닌 글자 모양으로 그리도록 변형 선택자를 붙인 문양
    var glyph: String { symbol + "\u{FE0E}" }
}

extension Card {
    var spokenName: String { "\(suit.spokenName) \(rankLabel)" }
}

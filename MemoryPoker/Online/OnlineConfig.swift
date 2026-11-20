import Foundation

/// 온라인 대전 서버 설정
enum OnlineConfig {
    /// 방 코드 중계 서버 — '기억의 만찬'과 같은 서버를 쓴다.
    /// 서버는 메시지 내용을 해석하지 않고 같은 방의 상대에게 그대로 넘겨주기만 한다.
    static let serverURL = URL(string: "wss://feast-of-memory.onrender.com")!

    /// 같은 서버를 쓰는 다른 게임의 방에 잘못 들어갔는지 가려내는 표시
    static let appID = "memory_poker"

    static let codeLength = 6
}

/// 상대 기기와 주고받는 메시지. 서버의 "move" 봉투에 실려 그대로 중계된다.
struct OnlineMessage: Codable, Equatable {
    enum Kind: String, Codable {
        /// 연결 직후 서로 보내는 인사 (app으로 같은 게임인지 확인)
        case hello
        /// 이번 판을 시작할 준비가 됨
        case ready
        /// 방장이 정한 판: 시드와 공개 시간. 양쪽이 같은 시드로 같은 카드를 깐다.
        case deal
        /// 고른 두 칸
        case pick
        /// 암기 위반(스크린샷)으로 이번 판을 몰수당함
        case forfeit
    }

    var kind: Kind
    var app: String?
    var round: Int?
    /// UInt64를 문자열로 (JSON 숫자는 2^53 위에서 깨진다)
    var seed: String?
    var seconds: Int?
    var a: Int?
    var b: Int?
}

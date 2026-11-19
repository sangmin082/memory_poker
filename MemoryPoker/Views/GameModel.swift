import Foundation
import Observation

enum GameMode: Hashable {
    /// 혼자서 최고의 조합 찾기
    case practice
    case vsBot(BotLevel)
    /// 한 기기로 둘이서
    case twoPlayer
}

/// 자리. 연습·컴퓨터 대전에서는 사람이 first, 컴퓨터가 second.
enum Seat: Hashable {
    case first, second

    var other: Seat { self == .first ? .second : .first }
}

enum Phase: Equatable {
    /// 카드가 덮인 채 시작을 기다린다
    case ready
    /// 16장 공개 (제한 시간)
    case memorize
    /// 공유 카드를 보고 말 2개를 놓는다
    case select(Seat)
    /// 2인 대전: 다음 사람에게 기기를 넘긴다
    case handoff(Seat)
    /// 카드 공개와 승패
    case reveal
}

/// 한 판의 결과
struct RoundResult: Equatable {
    let picks: [Seat: Pick]
    let values: [Seat: HandValue]
    /// 연습에서는 nil
    let outcome: Outcome?
    let bestValue: HandValue
    /// 최고의 조합이 되는 선택 하나 (누군가 찾았다면 그 선택)
    let bestPick: Pick

    /// first 자리가 최고의 조합을 찾았는가
    var isPerfect: Bool { values[.first] == bestValue }
    /// 누구든 최고의 조합을 찾았는가
    var bestWasFound: Bool { values.values.contains(bestValue) }
}

enum GameSettings {
    /// 기본 공개 시간(초)
    static let defaultMemorizeSeconds = 20
}

/// 한 판의 진행을 관리한다: 암기 타이머, 말 놓기, 컴퓨터의 선택, 공개, 전적 기록.
@MainActor
@Observable
final class GameModel {
    let mode: GameMode
    let memorizeDuration: Double

    private(set) var deal: Deal
    private(set) var phase: Phase = .ready
    /// 암기 단계의 남은 시간(초)
    private(set) var remaining: Double = 0
    /// 지금 고르는 사람이 말을 놓은 칸 (최대 2칸, 놓은 순서)
    private(set) var selection: [Int] = []
    private(set) var result: RoundResult?
    /// 이 화면에 들어온 뒤의 승수 (2인 대전 점수판)
    private(set) var sessionWins: [Seat: Int] = [.first: 0, .second: 0]
    /// 2인 대전에서 이번 판에 먼저 고르는 쪽 (판마다 바뀐다)
    private(set) var firstSelector: Seat = .first

    @ObservationIgnored private var picks: [Seat: Pick] = [:]
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var rng: SplitMix64
    @ObservationIgnored private var roundIndex = 0
    /// UI 테스트·스크린샷용: 0보다 크면 판마다 (시드 + 판 번호)로 카드를 깐다
    @ObservationIgnored private let fixedSeed: Int

    init(mode: GameMode) {
        self.mode = mode
        let defaults = UserDefaults.standard
        let seconds = defaults.integer(forKey: "memorizeTime")
        memorizeDuration = Double(seconds > 0 ? seconds : GameSettings.defaultMemorizeSeconds)
        let seed = defaults.integer(forKey: "uiTestSeed")
        fixedSeed = seed

        var generator = SplitMix64(seed: seed > 0 ? UInt64(seed) : UInt64.random(in: 0...UInt64.max))
        deal = Deal.random(using: &generator)
        rng = generator
    }

    // MARK: - 화면이 쓰는 상태

    var botLevel: BotLevel? {
        if case .vsBot(let level) = mode { return level }
        return nil
    }

    var isCardsFaceUp: Bool { phase == .memorize || phase == .reveal }

    var isCommunityVisible: Bool {
        switch phase {
        case .ready, .memorize: return false
        case .select, .handoff, .reveal: return true
        }
    }

    /// 지금 말을 놓고 있는 자리
    var selectingSeat: Seat? {
        if case .select(let seat) = phase { return seat }
        return nil
    }

    var canConfirm: Bool { selectingSeat != nil && selection.count == 2 }

    // MARK: - 진행

    func startMemorize() {
        guard phase == .ready else { return }
        phase = .memorize
        remaining = memorizeDuration
        Haptics.move()

        let deadline = Date().addingTimeInterval(memorizeDuration)
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled, self.phase == .memorize else { return }
                let left = deadline.timeIntervalSinceNow
                if left <= 0 {
                    self.finishMemorize()
                    return
                }
                // 마지막 3초는 초가 바뀔 때마다 톡톡
                if left <= 3, Int(left.rounded(.up)) != Int(self.remaining.rounded(.up)) {
                    Haptics.tap()
                }
                self.remaining = left
            }
        }
    }

    /// 시간이 끝났거나 "다 외웠어요"를 눌렀을 때: 카드를 덮고 공유 카드를 공개한다.
    func finishMemorize() {
        guard phase == .memorize else { return }
        timerTask?.cancel()
        remaining = 0
        selection = []
        phase = .select(firstSelector)
        Haptics.move()
    }

    /// 칸을 눌러 말을 놓거나 치운다. 세 번째 칸을 누르면 먼저 놓은 말을 옮긴다.
    func toggle(_ index: Int) {
        guard selectingSeat != nil, deal.board.indices.contains(index) else { return }
        if let position = selection.firstIndex(of: index) {
            selection.remove(at: position)
        } else {
            if selection.count == 2 { selection.removeFirst() }
            selection.append(index)
        }
        Haptics.tap()
    }

    func confirm() {
        guard let seat = selectingSeat, selection.count == 2 else { return }
        picks[seat] = Pick(selection[0], selection[1])
        selection = []

        switch mode {
        case .practice:
            reveal()
        case .vsBot(let level):
            picks[.second] = Bot.choosePick(deal: deal, level: level, using: &rng)
            reveal()
        case .twoPlayer:
            if picks.count == 2 {
                reveal()
            } else {
                phase = .handoff(seat.other)
                Haptics.move()
            }
        }
    }

    /// 2인 대전: 기기를 넘겨받은 사람이 준비됐다고 누른다.
    func acknowledgeHandoff() {
        guard case .handoff(let seat) = phase else { return }
        phase = .select(seat)
    }

    func nextRound() {
        timerTask?.cancel()
        roundIndex += 1
        if fixedSeed > 0 {
            var generator = SplitMix64(seed: UInt64(fixedSeed + roundIndex))
            deal = Deal.random(using: &generator)
        } else {
            deal = Deal.random(using: &rng)
        }
        picks = [:]
        selection = []
        result = nil
        remaining = 0
        if mode == .twoPlayer { firstSelector = firstSelector.other }
        phase = .ready
    }

    /// 화면을 떠날 때 타이머를 멈춘다.
    func stop() {
        timerTask?.cancel()
    }

    // MARK: - 공개

    private func reveal() {
        guard let firstPick = picks[.first] else { return }
        let best = deal.best()
        var values: [Seat: HandValue] = [.first: deal.value(for: firstPick)]
        var outcome: Outcome?

        if let secondPick = picks[.second] {
            values[.second] = deal.value(for: secondPick)
            outcome = deal.outcome(first: firstPick, second: secondPick)
        }

        // 누군가 최고의 조합을 찾았다면 그 선택에 별을 붙인다
        let foundBest = [Seat.first, .second]
            .compactMap { picks[$0] }
            .first { best.picks.contains($0) }

        let roundResult = RoundResult(
            picks: picks,
            values: values,
            outcome: outcome,
            bestValue: best.value,
            bestPick: foundBest ?? best.picks[0]
        )
        result = roundResult
        phase = .reveal
        record(roundResult)
    }

    private func record(_ result: RoundResult) {
        switch mode {
        case .practice:
            Stats.addPractice(perfect: result.isPerfect)
            result.isPerfect ? Haptics.success() : Haptics.failure()
        case .vsBot(let level):
            guard let outcome = result.outcome else { return }
            Stats.add(outcome, level: level)
            switch outcome {
            case .firstWins: Haptics.success()
            case .secondWins: Haptics.failure()
            case .draw: Haptics.move()
            }
        case .twoPlayer:
            switch result.outcome {
            case .firstWins?: sessionWins[.first, default: 0] += 1
            case .secondWins?: sessionWins[.second, default: 0] += 1
            default: break
            }
            Haptics.success()
        }
    }
}

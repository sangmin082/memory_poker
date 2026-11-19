import SwiftUI

struct GameScreen: View {
    @State private var model: GameModel

    init(mode: GameMode) {
        _model = State(initialValue: GameModel(mode: mode))
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 10) {
                header
                    .padding(.top, 4)

                communityRow

                BoardGridView(
                    cards: model.deal.board,
                    isFaceUp: model.isCardsFaceUp,
                    tokens: tokens,
                    dimmed: dimmedCells,
                    starred: starredCells,
                    isInteractive: model.selectingSeat != nil,
                    onTap: { model.toggle($0) }
                )

                footer
                    .frame(height: 148, alignment: .bottom)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if case .handoff(let seat) = model.phase {
                handoffCover(seat)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                modeTitle
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var modeTitle: some View {
        switch model.mode {
        case .practice:
            Text("연습")
        case .vsBot(let level):
            HStack(spacing: 5) {
                Text("컴퓨터 대전")
                Text("·")
                Text(level.label)
            }
        case .twoPlayer:
            Text("함께 하기")
        }
    }

    // MARK: - 게임판에 그릴 표시

    private var tokens: [Int: [Seat]] {
        var map: [Int: [Seat]] = [:]
        if let seat = model.selectingSeat {
            for index in model.selection { map[index] = [seat] }
        } else if model.phase == .reveal, let result = model.result {
            for seat in [Seat.first, .second] {
                guard let pick = result.picks[seat] else { continue }
                for index in pick.indices { map[index, default: []].append(seat) }
            }
        }
        return map
    }

    private var starredCells: Set<Int> {
        guard model.phase == .reveal, let result = model.result else { return [] }
        return Set(result.bestPick.indices)
    }

    private var dimmedCells: Set<Int> {
        guard model.phase == .reveal, let result = model.result else { return [] }
        var lit = Set(result.bestPick.indices)
        for pick in result.picks.values { lit.formUnion(pick.indices) }
        return Set(model.deal.board.indices).subtracting(lit)
    }

    // MARK: - 상단: 안내 / 결과

    private var header: some View {
        VStack(spacing: 4) {
            statusText
                .accessibilityIdentifier("status")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(model.phase == .reveal ? Theme.accent : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            hintText
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.phase {
        case .ready:
            Text("카드 16장을 외울 준비")
        case .memorize:
            Text("카드를 외우세요")
        case .select(let seat), .handoff(let seat):
            if model.mode == .twoPlayer {
                seat == .first ? Text("플레이어 1이 고를 차례") : Text("플레이어 2가 고를 차례")
            } else {
                Text("카드 2장을 고르세요")
            }
        case .reveal:
            resultText
        }
    }

    @ViewBuilder
    private var resultText: some View {
        if let result = model.result {
            switch (model.mode, result.outcome) {
            case (.twoPlayer, .firstWins?):
                Text("플레이어 1 승리!")
            case (.twoPlayer, .secondWins?):
                Text("플레이어 2 승리!")
            case (.vsBot, .firstWins?):
                Text("승리!")
            case (.vsBot, .secondWins?):
                Text("패배…")
            case (_, .draw?):
                Text("무승부")
            default:
                result.isPerfect ? Text("완벽! 최고의 조합입니다") : Text("아쉬워요, 더 높은 조합이 있었어요")
            }
        }
    }

    @ViewBuilder
    private var hintText: some View {
        switch model.phase {
        case .ready:
            Text("\(Int(model.memorizeDuration))초 동안 공개된 뒤 다시 덮입니다")
        case .memorize:
            Text("곧 카드가 덮이고 공유 카드 3장이 공개됩니다")
        case .select, .handoff:
            if model.mode == .twoPlayer {
                Text("상대는 화면을 보지 마세요")
            } else {
                Text("공유 카드 3장과 합쳐 가장 높은 조합을 만드세요")
            }
        case .reveal:
            if let result = model.result, !result.bestWasFound {
                Text("별 표시가 이 판에서 가장 높은 조합입니다")
            } else {
                Text("별 표시는 이 판에서 가장 높은 조합")
            }
        }
    }

    // MARK: - 공유 카드와 타이머

    private var communityRow: some View {
        VStack(spacing: 8) {
            ZStack {
                HStack(spacing: 8) {
                    ForEach(model.deal.community.indices, id: \.self) { index in
                        Group {
                            if model.isCommunityVisible {
                                CardFaceView(card: model.deal.community[index])
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    .accessibilityElement()
                                    .accessibilityIdentifier("community-\(index)")
                                    .accessibilityLabel(Text(model.deal.community[index].spokenName))
                            } else {
                                CardSlotView()
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(height: 70)
                    }
                }

                HStack(alignment: .center) {
                    Text("공유 카드")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    if model.phase == .memorize {
                        Text(verbatim: "\(Int(model.remaining.rounded(.up)))")
                            .font(.system(size: 34, weight: .bold, design: .serif).monospacedDigit())
                            .foregroundStyle(model.remaining <= 5 ? Theme.accent : Theme.ink)
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("timer")
                    }
                }
            }

            // 남은 시간 막대
            GeometryReader { proxy in
                let fraction = model.phase == .memorize ? max(0, min(1, model.remaining / model.memorizeDuration)) : 0
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.hairline)
                    Rectangle()
                        .fill(model.remaining <= 5 ? Theme.accent : Theme.ink)
                        .frame(width: proxy.size.width * fraction)
                        .animation(.linear(duration: 0.1), value: model.remaining)
                }
            }
            .frame(height: 3)
            .opacity(model.phase == .memorize ? 1 : 0)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 하단: 버튼 / 결과표

    @ViewBuilder
    private var footer: some View {
        switch model.phase {
        case .ready:
            VStack(spacing: 12) {
                recordLine
                Button("카드 공개") { model.startMemorize() }
                    .buttonStyle(InkButtonStyle(filled: true))
            }
        case .memorize:
            Button("다 외웠어요") { model.finishMemorize() }
                .buttonStyle(InkButtonStyle())
        case .select, .handoff:
            VStack(spacing: 12) {
                Text("놓은 말 \(model.selection.count)/2")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                Button("선택 완료") { model.confirm() }
                    .buttonStyle(InkButtonStyle(filled: true))
                    .disabled(!model.canConfirm)
                    .opacity(model.canConfirm ? 1 : 0.35)
            }
        case .reveal:
            if let result = model.result {
                VStack(spacing: 8) {
                    handRow(seat: .first, result: result)
                    if result.picks[.second] != nil {
                        handRow(seat: .second, result: result)
                    }
                    if !result.bestWasFound {
                        bestRow(result)
                    }
                    Button("한 판 더") { model.nextRound() }
                        .buttonStyle(InkButtonStyle(filled: true))
                        .padding(.top, 2)
                }
            }
        }
    }

    /// 시작 전에 보여 주는 전적 한 줄
    @ViewBuilder
    private var recordLine: some View {
        Group {
            switch model.mode {
            case .practice:
                let record = Stats.practice
                if record.played > 0 {
                    Text("최고의 조합 \(record.perfect)/\(record.played)판 · 연속 \(record.streak)판 (최고 \(record.bestStreak)판)")
                }
            case .vsBot(let level):
                let record = Stats.record(for: level)
                if record.total > 0 {
                    Text("전적 \(record.wins)승 \(record.losses)패 \(record.draws)무")
                }
            case .twoPlayer:
                let first = model.sessionWins[.first] ?? 0
                let second = model.sessionWins[.second] ?? 0
                if first + second > 0 {
                    Text("플레이어 1  \(first) : \(second)  플레이어 2")
                }
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(Theme.inkSoft)
        .accessibilityIdentifier("record")
    }

    private func seatName(_ seat: Seat) -> LocalizedStringKey {
        switch model.mode {
        case .practice:
            return "나"
        case .vsBot:
            return seat == .first ? "나" : "컴퓨터"
        case .twoPlayer:
            return seat == .first ? "플레이어 1" : "플레이어 2"
        }
    }

    private func isWinner(_ seat: Seat, _ result: RoundResult) -> Bool {
        switch result.outcome {
        case .firstWins?: return seat == .first
        case .secondWins?: return seat == .second
        default: return false
        }
    }

    /// "● 나   K♠ 7♦   풀하우스"
    private func handRow(seat: Seat, result: RoundResult) -> some View {
        HStack(spacing: 8) {
            TokenView(seat: seat)
                .frame(width: 16, height: 16)
            Text(seatName(seat))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 4)
            if let pick = result.picks[seat], let value = result.values[seat] {
                pickText(pick)
                Text(value.category.label)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(isWinner(seat, result) ? Theme.accent : Theme.ink)
                    .frame(minWidth: 84, alignment: .trailing)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(seat == .first ? "hand-first" : "hand-second")
    }

    private func bestRow(_ result: RoundResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.gold)
                .frame(width: 16, height: 16)
            Text("최고의 조합")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 4)
            pickText(result.bestPick)
            Text(result.bestValue.category.label)
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(minWidth: 84, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hand-best")
    }

    /// 고른 2장을 "K♠ 7♦"처럼 문양 색을 살려 쓴다.
    private func pickText(_ pick: Pick) -> some View {
        HStack(spacing: 6) {
            ForEach(pick.indices, id: \.self) { index in
                let card = model.deal.board[index]
                Text(verbatim: card.rankLabel + card.suit.glyph)
                    .foregroundStyle(Theme.color(for: card.suit))
                    .accessibilityLabel(Text(card.spokenName))
            }
        }
        .font(.system(.subheadline, design: .serif, weight: .semibold))
    }

    // MARK: - 2인 대전: 기기 넘기기

    private func handoffCover(_ seat: Seat) -> some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                TokenView(seat: seat)
                    .frame(width: 56, height: 56)

                (seat == .first ? Text("플레이어 1 차례") : Text("플레이어 2 차례"))
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)

                Text("기기를 넘겨받은 뒤 눌러 주세요.\n앞사람이 놓은 말은 보이지 않습니다.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSoft)

                Button("준비됐어요") { model.acknowledgeHandoff() }
                    .buttonStyle(InkButtonStyle(filled: true))
                    .frame(maxWidth: 220)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
        }
    }
}

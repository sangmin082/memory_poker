import SwiftUI

/// 카드 앞면: 숫자와 문양을 크게 한 번씩. 작은 크기에서도 읽히도록 장식은 넣지 않는다.
struct CardFaceView: View {
    let card: Card

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = width * 0.1

            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.cardFace)
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.ink.opacity(0.4), lineWidth: 1)

                VStack(spacing: -width * 0.06) {
                    Text(card.rankLabel)
                        .font(.system(size: width * 0.48, weight: .bold, design: .serif))
                    Text(card.suit.glyph)
                        .font(.system(size: width * 0.42))
                }
                .foregroundStyle(Theme.color(for: card.suit))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: width, height: proxy.size.height)
            }
        }
        .aspectRatio(5.0 / 7.0, contentMode: .fit)
    }
}

/// 카드 뒷면: 잉크 바탕에 마름모 격자
struct CardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = width * 0.1

            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.ink)

                Canvas { context, size in
                    var path = Path()
                    let step = max(4, size.width / 4)
                    var x = -size.height
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        path.move(to: CGPoint(x: x + size.height, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    context.stroke(path, with: .color(Theme.paper.opacity(0.22)), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius * 0.5))
                .padding(width * 0.1)

                RoundedRectangle(cornerRadius: radius * 0.5)
                    .strokeBorder(Theme.paper.opacity(0.45), lineWidth: 1)
                    .padding(width * 0.1)
            }
        }
        .aspectRatio(5.0 / 7.0, contentMode: .fit)
    }
}

/// 뒤집을 수 있는 카드
struct PlayingCardView: View {
    let card: Card
    let isFaceUp: Bool

    var body: some View {
        ZStack {
            CardBackView()
                .opacity(isFaceUp ? 0 : 1)
            CardFaceView(card: card)
                .opacity(isFaceUp ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFaceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .animation(.easeInOut(duration: 0.4), value: isFaceUp)
    }
}

/// 아직 공개되지 않은 공유 카드 자리
struct CardSlotView: View {
    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: proxy.size.width * 0.1)
                .strokeBorder(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .aspectRatio(5.0 / 7.0, contentMode: .fit)
    }
}

/// 게임 말: 카드 위에 올려 선택을 표시한다.
struct TokenView: View {
    let seat: Seat

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Theme.color(for: seat))
                Circle()
                    .strokeBorder(Theme.paper, lineWidth: max(1, side * 0.09))
                Circle()
                    .strokeBorder(Theme.paper.opacity(0.7), lineWidth: max(0.5, side * 0.04))
                    .padding(side * 0.24)
            }
            .frame(width: side, height: side)
            .shadow(color: Theme.ink.opacity(0.3), radius: side * 0.08, y: side * 0.05)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 카드 버튼: 눌렀을 때 살짝 줄어들 뿐, 비활성 상태에서도 흐려지지 않는다.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 4×4 게임판
struct BoardGridView: View {
    let cards: [Card]
    let isFaceUp: Bool
    /// 칸마다 올라간 말
    var tokens: [Int: [Seat]] = [:]
    /// 공개 단계에서 흐리게 할 칸 (아무도 고르지 않은 카드)
    var dimmed: Set<Int> = []
    /// 최고의 조합이 되는 칸
    var starred: Set<Int> = []
    var isInteractive: Bool = false
    var onTap: (Int) -> Void = { _ in }

    private let columns = 4
    private let gap: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let rows = cards.count / columns
            let widthLimit = (proxy.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let heightLimit = (proxy.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows) * 5 / 7
            let cardWidth = max(10, min(widthLimit, heightLimit))
            let cardHeight = cardWidth * 7 / 5

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            cell(row * columns + column, width: cardWidth)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func cell(_ index: Int, width: CGFloat) -> some View {
        let seats = tokens[index] ?? []
        let isStarred = starred.contains(index)

        return Button {
            onTap(index)
        } label: {
            PlayingCardView(card: cards[index], isFaceUp: isFaceUp)
                .overlay {
                    // 뒷면일 때: 카드 한가운데에 말을 올린다
                    if !isFaceUp, let seat = seats.first {
                        TokenView(seat: seat)
                            .frame(width: width * 0.56, height: width * 0.56)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay {
                    // 앞면일 때: 고른 사람의 색으로 테두리를 두른다
                    if isFaceUp, let seat = seats.first {
                        RoundedRectangle(cornerRadius: width * 0.1)
                            .strokeBorder(Theme.color(for: seat), lineWidth: max(2, width * 0.05))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isFaceUp, !seats.isEmpty {
                        HStack(spacing: -width * 0.06) {
                            ForEach(seats, id: \.self) { seat in
                                TokenView(seat: seat)
                                    .frame(width: width * 0.3, height: width * 0.3)
                            }
                        }
                        .offset(x: width * 0.08, y: -width * 0.08)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isFaceUp, isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: width * 0.2))
                            .foregroundStyle(Theme.gold)
                            .padding(width * 0.07)
                    }
                }
                .opacity(dimmed.contains(index) ? 0.4 : 1)
                .animation(.spring(duration: 0.25), value: seats)
                .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .disabled(!isInteractive)
        .accessibilityIdentifier("card-\(index)")
        .accessibilityLabel(Text(accessibilityText(index, seats: seats, isStarred: isStarred)))
        .accessibilityAddTraits(!isFaceUp && !seats.isEmpty ? .isSelected : [])
    }

    private func accessibilityText(_ index: Int, seats: [Seat], isStarred: Bool) -> String {
        var parts: [String] = []
        if isFaceUp {
            parts.append(cards[index].spokenName)
            if isStarred { parts.append(String(localized: "최고의 조합")) }
        } else {
            parts.append(String(localized: "뒤집힌 카드"))
        }
        if !seats.isEmpty { parts.append(String(localized: "말 놓음")) }
        return parts.joined(separator: ", ")
    }
}

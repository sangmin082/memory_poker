import SwiftUI

/// 규칙과 족보 한 장
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Ranking: Identifiable {
        let category: HandCategory
        let detail: LocalizedStringKey
        /// 예시 5장. 족보를 이루지 않는 카드는 흐리게 그린다.
        let example: [Card]
        var id: Int { category.rawValue }
    }

    private static func cards(_ text: String) -> [Card] {
        text.split(separator: " ").compactMap { Card(String($0)) }
    }

    /// 강한 순서
    private static let rankings: [Ranking] = [
        Ranking(category: .straightFlush, detail: "숫자가 이어지고 문양이 같은 카드 5장", example: cards("9H 8H 7H 6H 5H")),
        Ranking(category: .fourOfAKind, detail: "숫자가 같은 카드 4장", example: cards("QS QH QD QC 4S")),
        Ranking(category: .fullHouse, detail: "트리플 + 페어", example: cards("JS JH JD 8C 8S")),
        Ranking(category: .flush, detail: "문양이 같은 카드 5장", example: cards("AD JD 8D 6D 3D")),
        Ranking(category: .straight, detail: "숫자가 이어지는 카드 5장", example: cards("TS 9H 8D 7C 6S")),
        Ranking(category: .threeOfAKind, detail: "숫자가 같은 카드 3장", example: cards("7S 7H 7D KC 2S")),
        Ranking(category: .twoPair, detail: "2쌍의 페어", example: cards("KS KH 5D 5C 9S")),
        Ranking(category: .onePair, detail: "숫자가 같은 카드 2장", example: cards("AS AH QD 8C 3S")),
        Ranking(category: .highCard, detail: "어떤 족보도 아닐 때, 가장 높은 카드 1장", example: cards("AS JH 8D 6C 2S")),
    ]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("규칙과 족보")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button("닫기") { dismiss() }
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 12) {
                        ruleLine("52장 중 무작위 16장이 정해진 시간 동안 공개됩니다. 자리까지 외우세요.")
                        ruleLine("카드가 덮이면 공유 카드 3장이 공개됩니다.")
                        ruleLine("외워 둔 16장 중 2장의 자리에 말을 놓습니다. 공유 카드 3장과 합친 5장이 내 조합입니다.")
                        ruleLine("두 사람이 모두 고르면 카드를 공개하고, 더 높은 조합을 만든 쪽이 이깁니다. 같은 카드를 골라도 됩니다.")
                        ruleLine("카드가 공개된 동안 화면을 캡처하면 암기 위반으로 그 판은 몰수패입니다. 화면 녹화 중에는 카드가 가려집니다.")
                    }

                    Text("족보 (강한 순서)")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Self.rankings) { ranking in
                            rankingRow(ranking)
                        }
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }

                    Text("같은 족보라면")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ruleLine("족보를 이루는 숫자가 더 높은 쪽이 이깁니다. A가 가장 높고 2가 가장 낮습니다.")
                        ruleLine("그것도 같으면 나머지 카드의 숫자가 더 높은 쪽이 이깁니다.")
                        ruleLine("문양은 비교하지 않습니다. 끝까지 같으면 무승부입니다.")
                        ruleLine("A-2-3-4-5는 5가 가장 높은 스트레이트로 칩니다.")
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 28)
            }
        }
        .presentationDetents([.large])
    }

    private func rankingRow(_ ranking: Ranking) -> some View {
        let core = Set(HandEvaluator.coreCards(ranking.example))

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ranking.category.label)
                        .font(.system(.body, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(ranking.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                HStack(spacing: 3) {
                    ForEach(ranking.example, id: \.self) { card in
                        CardFaceView(card: card)
                            .frame(width: 26)
                            .opacity(core.contains(card) ? 1 : 0.4)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
        }
    }

    private func ruleLine(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("—")
                .foregroundStyle(Theme.accent)
                .font(.system(.body, weight: .bold))
            Text(text)
                .font(.system(.callout))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

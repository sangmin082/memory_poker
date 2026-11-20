import SwiftUI

struct HomeView: View {
    @AppStorage("botLevel") private var botLevel: BotLevel = .normal
    @AppStorage("memorizeTime") private var memorizeTime: Int = GameSettings.defaultMemorizeSeconds
    @State private var showRules = false

    private let timeOptions = [10, 20, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    wordmark
                        .padding(.top, 24)

                    Spacer()

                    menu

                    Spacer()

                    Button {
                        showRules = true
                    } label: {
                        Text("규칙과 족보 보기")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRules) { RulesView() }
        }
        .tint(Theme.ink)
    }

    // MARK: - 워드마크

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 미니 카드 석 장: 덮인 카드 사이에서 기억해 둔 한 장
            HStack(spacing: -12) {
                CardBackView()
                    .frame(width: 40)
                    .rotationEffect(.degrees(-9))
                CardFaceView(card: Card(rank: 14, suit: .spades))
                    .frame(width: 40)
                    .offset(y: -6)
                    .zIndex(1)
                CardBackView()
                    .frame(width: 40)
                    .rotationEffect(.degrees(9))
            }
            .frame(height: 64)
            .padding(.leading, 4)
            .accessibilityHidden(true)

            Text("기억 포커")
                .font(.system(size: 40, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("외우고, 고르고, 가장 높은 패를")
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - 메뉴

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("16장을 외운 뒤 2장을 골라 공유 카드 3장과 조합")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .padding(.bottom, 18)

            menuRow(title: "연습", detail: "혼자서 최고의 조합 찾기") {
                GameScreen(mode: .practice)
            }
            menuRow(title: "컴퓨터 대전", detail: "기억력이 다른 세 상대") {
                GameScreen(mode: .vsBot(botLevel))
            }

            textToggle(BotLevel.allCases, selection: $botLevel) { level in
                Text(level.label)
            }
            .padding(.top, 2)
            .padding(.bottom, 18)

            menuRow(title: "함께 하기", detail: "한 기기로 둘이서") {
                GameScreen(mode: .twoPlayer)
            }
            menuRow(title: "온라인 대전", detail: "방 코드로 각자의 기기에서") {
                OnlineLobbyView()
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 16) {
                Text("카드 공개 시간")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                textToggle(timeOptions, selection: $memorizeTime) { seconds in
                    Text("\(seconds)초")
                }
            }
            .padding(.top, 18)
        }
    }

    /// 밑줄로 선택을 표시하는 텍스트 토글
    private func textToggle<Option: Hashable, Label: View>(
        _ options: [Option], selection: Binding<Option>,
        @ViewBuilder label: @escaping (Option) -> Label
    ) -> some View {
        HStack(spacing: 20) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                    Haptics.tap()
                } label: {
                    label(option)
                        .font(.system(.subheadline, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.inkSoft)
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Rectangle()
                                    .fill(Theme.accent)
                                    .frame(height: 2)
                                    .offset(y: 4)
                            }
                        }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.leading, 2)
    }

    private func menuRow<Destination: View>(
        title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            NavigationLink {
                destination()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
        }
    }
}

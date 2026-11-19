# 기억 포커 — iOS

16장을 외우고, 2장을 골라, 공유 카드 3장과 가장 높은 조합을 만드는 게임. SwiftUI로 만든 네이티브 iOS 앱.

- Bundle ID: `com.memorypoker.game`
- 완전 오프라인 · 데이터 수집 없음 · 한국어/영어

## 게임 규칙

1. 52장 중 무작위 16장이 4×4로 **20초 동안** 공개된다.
2. 카드가 덮이고 **공유 카드 3장**이 공개된다.
3. 외워 둔 16장 중 2장의 자리에 **말을 놓는다**. 그 2장 + 공유 카드 3장 = 내 5장 조합.
4. 두 사람이 다 고르면 카드를 공개하고, 더 높은 조합이 이긴다.

족보는 홀덤과 같다(스트레이트 플러시 > 포카드 > 풀하우스 > 플러시 > 스트레이트 > 트리플 > 투페어 > 원페어 > 하이카드).
같은 족보면 족보를 이루는 숫자, 그다음 나머지 카드의 숫자를 비교하고 문양은 비교하지 않는다. 끝까지 같으면 무승부.

## 앱 구성

```
MemoryPoker/
  App/      MemoryPokerApp.swift
  Engine/   Card.swift(카드·덱·시드 난수) Hand.swift(족보 판정·비교) Deal.swift(판·선택·최고 조합)
  AI/       Bot.swift (불완전한 기억 + 완전한 수읽기 / 쉬움·보통·어려움)
  Views/    HomeView / GameScreen / GameModel(진행·타이머) / CardView(카드·말·게임판) / RulesView / Theme / Stats / Haptics
Tests/MemoryPokerCoreTests/   엔진·AI 단위 테스트 (Package.swift)
MemoryPokerUITests/           시뮬레이터 플레이 테스트, 스토어 스크린샷
```

- **연습**: 혼자서 이 판의 최고 조합 찾기. 찾은 횟수와 연속 기록이 쌓인다.
- **컴퓨터 대전**: 쉬움/보통/어려움, 난이도별 전적.
- **함께 하기**: 한 기기로 2인 대전. 같이 외운 뒤 번갈아 고르고(기기를 넘길 때 앞사람의 말은 가려진다), 판마다 먼저 고르는 사람이 바뀐다.
- **카드 공개 시간**: 10초 / 20초(기본) / 30초.
- 공개 단계에서 이 판의 **최고 조합**에 별 표시.

### 정해 둔 세부 규칙

원문 규칙에 없는 부분은 이렇게 정했다.

- 두 사람이 **같은 카드를 골라도 된다** (각자 자기 게임판에 말을 놓는 방식이므로).
- A-2-3-4-5는 5가 가장 높은 스트레이트. K-A-2처럼 A를 가운데 낀 것은 스트레이트가 아니다.
- 세 번째 칸을 누르면 먼저 놓은 말이 그 칸으로 옮겨 간다. 놓은 말을 다시 누르면 치워진다.
- 암기 시간이 남아도 "다 외웠어요"로 바로 넘어갈 수 있다. 고르는 데는 시간 제한이 없다.

### AI 메모

컴퓨터는 수읽기(120가지 선택 전부 비교)는 완벽하고 **기억력**으로만 난이도가 갈린다.
카드마다 정확히 기억 / 헷갈림(문양 또는 숫자 ±1) / 잊음 중 하나가 되고, 기억하는 대로 가장 높은 조합을 고른다.

| 난이도 | 정확히 | 헷갈림 | 잊음 | 최고 조합을 찾는 비율 |
|---|---|---|---|---|
| 쉬움 | 45% | 20% | 35% | 약 33% |
| 보통 | 70% | 15% | 15% | 약 59% |
| 어려움 | 92% | 5% | 3% | 약 90% |

## 빌드

로컬(Mac): `MemoryPoker.xcodeproj`를 Xcode 26+로 열고 실행.
엔진 테스트는 Mac 없이도 가능: `swift test` (리눅스 Swift 툴체인 OK).

CI (GitHub Actions):

- `.github/workflows/ios.yml` — push/PR 시 엔진 테스트 + 서명 없이 컴파일 검증
- `.github/workflows/ui-tests.yml` — 시뮬레이터에서 주요 흐름을 눌러 보고 스크린샷을 아티팩트로 남김
- `.github/workflows/store-screenshots.yml` — App Store용 6.9" 스크린샷(한국어·영어)
- `.github/workflows/testflight.yml` — Actions 탭 Run workflow 또는 `v*` 태그 푸시 시 TestFlight 업로드
  (다른 앱들과 같은 방식: `scripts/asc.py`가 번들 ID 등록·빌드 번호 결정, fastlane match 서명)

UI 테스트는 `-uiTestSeed <n>`(판 고정)과 `-memorizeTime <초>` 실행 인자를 쓴다.

시크릿과 첫 배포 절차는 [docs/RELEASE.md](./docs/RELEASE.md), 스토어 제출 문구는 [docs/APP_STORE.md](./docs/APP_STORE.md) 참고.

# 기억 포커 — iOS

16장을 외우고, 2장을 골라, 공유 카드 3장과 가장 높은 조합을 만드는 게임. SwiftUI로 만든 네이티브 iOS 앱.

- Bundle ID: `com.memorypoker.game`
- 데이터 수집 없음 · 한국어/영어 · 온라인 대전 말고는 인터넷 없이 동작

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
  Online/   OnlineConfig.swift(서버 주소·메시지) RoomClient.swift(WebSocket 방 만들기·입장·중계)
  Views/    HomeView / GameScreen / GameModel(진행·타이머·온라인 동기화) / OnlineLobbyView / CardView(카드·말·게임판) / RulesView / Theme / Stats / Haptics
Tests/MemoryPokerCoreTests/   엔진·AI 단위 테스트 (Package.swift)
MemoryPokerUITests/           시뮬레이터 플레이 테스트, 스토어 스크린샷
```

- **연습**: 혼자서 이 판의 최고 조합 찾기. 찾은 횟수와 연속 기록이 쌓인다.
- **컴퓨터 대전**: 쉬움/보통/어려움, 난이도별 전적.
- **함께 하기**: 한 기기로 2인 대전. 같이 외운 뒤 번갈아 고르고(기기를 넘길 때 앞사람의 말은 가려진다), 판마다 먼저 고르는 사람이 바뀐다.
- **온라인 대전**: 방을 만들면 6자리 코드가 나오고, 상대가 코드를 넣으면 각자의 기기에서 겨룬다.
- **캡처 방지**: 카드가 공개된 동안 스크린샷을 찍으면 암기 위반으로 그 판은 몰수패(연습·한 기기 2인은 무효).
  화면 녹화·미러링 중에는 카드가 가려진다.
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

### 온라인 대전 메모

- 서버는 '기억의 만찬'의 중계 서버(`wss://feast-of-memory.onrender.com`, `feast_of_memory/server`)를 **같이 쓴다**.
  이 서버는 방 코드로 두 사람을 묶고 `move` 메시지를 내용을 보지 않고 상대에게 넘기기만 하므로 고칠 것이 없었다.
  방 코드는 두 게임이 함께 쓰는데, 연결 직후 `hello`로 같은 게임인지 확인해 다른 게임의 방이면 바로 끊는다.
  서버를 따로 두려면 그 `server/`를 새 Render 서비스로 올리고 `OnlineConfig.serverURL`만 바꾸면 된다.
- 판은 방장(방을 만든 쪽)이 정한다. 둘 다 '준비 완료'를 누르면 방장이 시드와 공개 시간을 보내고,
  양쪽이 같은 시드로 같은 16장+3장을 깐다(`Deal.random`은 직접 섞어서 기기가 달라도 결과가 같다).
- 각자 자기 기기의 타이머로 외우고 고른다. 고른 칸을 서로 보내고, 둘 다 고르면 공개한다.
- 메시지: `hello` / `ready{round}` / `deal{round,seed,seconds}` / `pick{round,a,b}` / `forfeit{round}`.
- 믿고 하는 친구 대전용이다. 고른 칸을 그대로 보내므로 변조한 앱까지 막지는 않는다.

## 빌드

로컬(Mac): `MemoryPoker.xcodeproj`를 Xcode 26+로 열고 실행.
엔진 테스트는 Mac 없이도 가능: `swift test` (리눅스 Swift 툴체인 OK).

CI (GitHub Actions):

- `.github/workflows/ios.yml` — push/PR 시 엔진 테스트 + 서명 없이 컴파일 검증
- `.github/workflows/ui-tests.yml` — 시뮬레이터에서 주요 흐름을 눌러 보고 스크린샷을 아티팩트로 남김
  (온라인 대전은 테스트가 WebSocket으로 직접 상대 역할을 한다. 서버에 닿지 않으면 건너뛴다)
- `.github/workflows/pages.yml` — `docs/`의 지원·개인정보 페이지를 gh-pages 브랜치로 복사
- `.github/workflows/store-screenshots.yml` — App Store용 6.9" 스크린샷(한국어·영어)
- `.github/workflows/testflight.yml` — Actions 탭 Run workflow 또는 `v*` 태그 푸시 시 TestFlight 업로드
  (다른 앱들과 같은 방식: `scripts/asc.py`가 번들 ID 등록·빌드 번호 결정, fastlane match 서명)

UI 테스트는 `-uiTestSeed <n>`(판 고정)과 `-memorizeTime <초>` 실행 인자를 쓴다.

시크릿과 첫 배포 절차는 [docs/RELEASE.md](./docs/RELEASE.md), 스토어 제출 문구는 [docs/APP_STORE.md](./docs/APP_STORE.md) 참고.

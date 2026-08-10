# CLAUDE.md

이 저장소에서 작업할 때 참고할 맥락입니다.

## 프로젝트

지원 종료된 교보문고 **크레마 카르타** e-ink 리더기를 **시계·캘린더 상시 표시용 e-ink 디스플레이**로 재활용하는 개인 토이 프로젝트.

- **핵심 산출물**: KOReader용 **Lua 플러그인** (처음부터 직접 작성 — 기존 플러그인 재사용 아님)
- **타깃 기기**: 크레마 카르타 / 카르타G 롬 / 안드로이드 4.4.2 / 샌디스크 16GB microSD
- **현재 상태**: KOReader 설치 및 e-ink 호환성 확인 완료. 플러그인 코드는 아직 없음.

### 기기 정보 (KOReader 호환성 테스트로 확인, 2026-08-08)

```
Manufacturer: iwg        Brand: crema         Model: crema-0670c
Device: ntx_6sl          Product: ntx_6sl     Hardware: e60qg0
Platform: imx6
```

**Device already supported** — `EPD: freescale`, `Lights: tolino`.
NTX 보드 + i.MX6 SoloLite 조합으로, Kobo·Tolino 기기와 같은 하드웨어 계열이다.
**TEST E-INK 실행 시 화면 전체 플래시 확인 — 목록 등재뿐 아니라 실동작까지 검증됨.**

기타: 안드로이드 4.4.2 / 시스템 v9.0.38 / 서점사 예스24 / 내부 저장소 5.86GB / 외부(microSD) 14.83GB.

### Lua 실행 환경 (canary 실기 확인, 2026-08-10)

`cremaclock.koplugin` canary 를 기기에서 실행해 얻은 실측값이다:

```
lua:      Lua 5.1              (LuaJIT — 구문 검사는 5.1 기준으로 할 것)
koreader: v2026.07.1
model:    ntx_6sl
datadir:  /storage/emulated/0/koreader
time:     2026-08-10 23:30:34  (기기 로컬 시각과 일치)
```

같이 확정된 것:

- **`os.date`/`os.time` 이 올바른 로컬 시각을 반환한다.** 타임존 보정 코드 불필요 —
  시계 프로젝트의 전제가 성립함.
- `WidgetContainer:extend` 와 `sorting_hint = "more_tools"` 가 이 버전에서 유효하다.
  구형 `:new{}` 서브클래싱 관용구를 쓸 이유가 없다.
- `datadir` 이 외부 저장소이므로 **플러그인 설정 파일도 여기에 두면 된다.**
- **`pcall` + `InfoMessage` 화면 로그 채널이 실제로 동작한다.** 값을 읽어낼 수 있음이
  확인됐으므로, 앞으로 모든 디버깅은 이 방식으로 한다.

설치본: `koreader-android-arm-v2026.07.1.apk` (armeabi-v7a). 설치 경로는 크레마 **열린서재 → `+`**.

### 파일 전송 통로

- **Send Anywhere** 로 PC → 크레마 전송. KOReader APK도 이 경로로 설치했다. 앞으로 플러그인 파일도 이 채널을 쓴다.
- **adb는 사용 불가.** 크레마 설정은 안드로이드 기본 설정 앱이 아닌 자체 화면이라 기기 정보에 빌드 번호 항목이 없고, 개발자 옵션을 켤 수 없다. 루팅 없이는 막혀 있으므로 파고들지 말 것.
- 윈도우 PC는 인식하지만 노출되는 드라이브가 읽기 전용이라 쓰기 불가.

#### USB 연결 (맥, 2026-08-10 확인)

맥에서 USB 기기 자체는 **정상 열거된다**. 이전에 "USB 트리에 열거되지 않는다"고 기록했던 것은 사실과 다름:

```
CREMA-0670C   idVendor=0x1F85 (IWG)  idProduct=0x6155
              Serial=CREMA359B04545  High Speed  bDeviceClass=0
```

다만 **데이터 통로는 열리지 않는다** — `adb devices` 비어 있음, `/Volumes` 마운트 없음,
`diskutil list external` 없음, USB 시리얼 노드 없음. `bDeviceClass=0`인데 매칭된
인터페이스 드라이버가 없는 상태로, 기기가 MTP 모드이고 macOS가 MTP를 네이티브
지원하지 않는 것이 원인으로 추정된다. 윈도우에서만 보였던 것과 일치한다.

**결론: USB는 개발에 쓰지 않는다.** 아래 배포 경로로 충분하므로 더 파지 말 것.

### 플러그인 배포 경로 (2026-08-10 확정)

```
/storage/emulated/0/koreader/plugins/<이름>.koplugin/
```

- KOReader 안드로이드 빌드는 내장 플러그인을 APK 에셋에서 앱 전용 디렉터리로 풀고,
  외부 저장소의 위 경로는 **사용자 플러그인 전용 드롭 지점**으로 따로 스캔한다.
  현재 비어 있는 것이 정상 상태다.
- 투입 절차 — USB·adb·루팅·microSD 분리 모두 불필요:
  1. Send Anywhere 로 `.koplugin` 폴더를 기기에 전송 (→ `0/Download/`)
  2. KOReader 파일 브라우저에서 롱프레스 → 복사 → `0/koreader/plugins/` 에 붙여넣기
  3. KOReader 재시작 후 메뉴에 항목이 뜨는지 확인
- KOReader 파일 브라우저는 문서 파일만 보이도록 필터링될 수 있다. `.lua` 가 안 보이면
  설정에서 **모든 파일 표시(Show unsupported files)** 를 켠다.

### 용어 주의: "개발자 옵션"이 두 개다

문서에서 이 말이 나오면 어느 쪽인지 반드시 구분할 것. 서로 무관하다.

| | 크레마(안드로이드) 설정 | KOReader 설정 |
|---|---|---|
| 레벨 | OS | 앱 |
| 개발자 옵션 | **켤 수 없음** — 빌드 번호 항목이 없음 | 사용 가능 |
| 용도 | adb, USB 디버깅 | e-ink 호환성 테스트, 로그 |
| 상태 | 포기 확정 (파지 말 것) | 활용 중 |

KOReader 쪽 경로: `Tools(렌치) → More tools → Developer options`.
2026-08-08 e-ink 호환성 테스트를 여기서 실행했다.

## 개발 시 유의사항

- 타깃이 **안드로이드 4.4.2 (KitKat)** 로 매우 구형이다. 최신 API·툴체인 가정 금지. KOReader 및 Lua 환경 제약을 항상 고려할 것.

### 디버깅 수단 — 화면 표시가 유일하다 (2026-08-10 확인)

**읽을 수 있는 로그가 없다.** 확인한 경로를 모두 적어둔다. 다시 시도하지 말 것:

| 경로 | 결과 |
|---|---|
| adb logcat | adb 자체가 불가 |
| `koreader/crash.log` | **안드로이드 빌드는 생성하지 않음.** 아래 설명 참조 |
| 서드파티 logcat 앱 | 안드로이드 4.1+ 는 `READ_LOGS` 가 시스템 앱 전용. 루팅 필요 |
| Developer options 의 로그 덤프 | 해당 항목 없음 (`디버그 로깅`, `C 블리터 비활성` 두 개뿐) |

`crash.log` 는 이름과 달리 크래시 전용이 아니라 stdout/stderr 전체 로그다. 다만 그건
셸 스크립트로 실행되는 플랫폼(데스크톱·Kobo·Kindle) 얘기고, **안드로이드는 자바
런처(`org.koreader.launcher`)로 뜨기 때문에 리다이렉트 대상이 없어 파일이 안 생긴다.**
로그는 logcat 으로만 나간다. Developer options 의 `디버그 로깅` 을 켜도 읽을 수 없다.

**그래서 로그 채널을 코드 안에 직접 만든다.** 위험한 작업은 `pcall` 로 감싸고 실패 시
`InfoMessage` 로 화면에 띄운다 (`cremaclock.koplugin/main.lua` 의 `notify`/`guard` 참조).

이 방식의 한계가 작업 방식을 규정한다 — **플러그인이 로드 자체에 실패하면 그 코드도
안 돌아가고, 신호는 "메뉴에 항목이 안 뜬다" 하나로 뭉개진다.** 따라서:

- `init()` 과 메뉴 등록 경로에는 실패할 여지가 있는 호출을 두지 않는다
- 위험한 일은 전부 콜백 안쪽 `pcall` 로 밀어넣는다
- 기기 왕복(Send Anywhere → 수동 복사 → 재시작)이 비싸므로 한 번에 최대한 많이 확인한다
- 코드를 크게 쓰지 말고 **작은 단위로 올려 확인하며 키워 나갈 것**

### C 블리터 비활성

`Developer options` 에 있지만 **켜지 말 것.** 화면 그리기를 C 대신 Lua 로 떨어뜨리는
렌더링 폴백이다. 카르타는 `EPD: freescale` 로 정상 지원되므로 불필요하고, 켜면 e-ink
갱신이 느려져 갱신 성능을 오판하게 된다. 화면 깨짐이 실제로 발생하면 그때 쓸 카드.

## 저장소 구조

```
plugins/cremaclock.koplugin/   ← 기기의 koreader/plugins/ 에 그대로 복사되는 단위
    _meta.lua                  플러그인 메타데이터
    main.lua                   WidgetContainer 구현
docs/                          조사·설계 문서
```

`plugins/` 아래 디렉터리 구조는 **기기 배치와 1:1로 일치시킨다.** 폴더 이름 규칙은
`<이름>.koplugin` 이며 이 규칙을 벗어나면 KOReader 가 스캔하지 않는다.

로컬에 Lua 런타임이 없다. 구문 검증은 Node + `luaparse` 로 한다 (brew 는 Xcode
라이선스 동의가 막혀 있음):

```sh
mkdir -p /tmp/luacheck && cd /tmp/luacheck && npm i luaparse
# luaVersion '5.1' 로 파싱 — KOReader 는 LuaJIT(5.1 문법) 기반
```

## 저장소 / 계정

- **개인** 토이 프로젝트. 코드는 개인 GitHub 계정 `bbjoony`에 저장.
- 업무용 계정과 **분리 관리**. 이 저장소의 로컬 git 신원은 `bbjoony`로 설정되어 있음 — 커밋에 업무용 이메일이 섞이지 않도록 유지할 것.

## 작업 방식

이 저장소는 **Public** 입니다. Claude Desktop은 GitHub 커넥터 없이 raw URL을 직접 읽습니다 (커넥터 연동은 2026-08-08 시도 후 폐기).

| 도구 | 역할 | 접근 방식 |
|------|------|-----------|
| Claude Desktop | 설계 논의, 사례 조사, 요구사항 정리 | `raw.githubusercontent.com/bbjoony/crema-project/main/...` 웹 fetch |
| Claude Code | 파일 작성, 커밋, 실제 개발 | 로컬 클론 `~/crema-project` 직접 |

## 다음 단계

사례 조사 완료 → [docs/research-koreader-plugins.md](docs/research-koreader-plugins.md). 리스크가 큰 순서로 재정렬됨.

1. ~~**KOReader 설치 + e-ink 호환성 테스트**~~ — 완료 (2026-08-08). Device already supported
2. ~~개발/디버깅 환경 확인 및 플러그인 배포 경로 결정~~ — 완료 (2026-08-10). adb 불가 확정, 배포 경로 확정
3. ~~**canary 실기 구동**~~ — 완료 (2026-08-10). 로드·화면 로그 채널 모두 성공. 위 Lua 실행 환경 절 참조
4. ~~**안드로이드 절전 억제 확인**~~ — **해소 (2026-08-10).** `설정 → Screen timeout → Keep screen on` 선택 가능, 활성화 완료. `needsWakelocks()` 가 거짓이고 `WRITE_SETTINGS` 권한도 불필요. **상시 표시 전제 성립.** 플러그인에서 wake lock 을 구현할 필요 없음
5. `digitalclock.koplugin` 재사용 여부 결정 ← **다음 세션 시작점. 미결정.**

### 결정 대기: digitalclock 재사용 범위 (2026-08-10 보류)

검증은 전부 끝났고 코드 작성 직전에서 멈췄다. 이 결정만 하면 바로 착수할 수 있다.
상세 분석은 [docs/research-koreader-plugins.md](docs/research-koreader-plugins.md) 1-b 절.

| 안 | 내용 | 대가 |
|---|---|---|
| **A. 기법만 참조** | 분경계 정렬·부분갱신 Geom 등 기법만 가져와 `cremaclock` 을 직접 키움 | 작업량 많음 / 라이선스 자유, 원래 방향 유지 |
| **B. 포크** | 293줄을 가져와 수정 | 가장 빠름 / **저장소가 AGPL-3.0 이 되고 출처 표기 필수** |
| **C. 먼저 그대로 설치** | 수정 없이 올려 상시 표시·전력·레이아웃을 체감한 뒤 결정 | 결정이 늦어짐 / 실측 정보를 얻음 |

이 결정이 필요한 이유: 이 문서 위쪽에 **"처음부터 직접 작성 — 기존 플러그인 재사용
아님"** 으로 방향을 못박아 두었다. B 를 고르면 그 방향과 라이선스 전제가 함께 바뀐다.

어느 안이든 공통으로 해야 하는 일:

- `_pauseAutoSuspend()` 는 카르타에서 불필요 (`Keep screen on` 설정이 대신함)
- `logger.dbg` 는 안드로이드에서 읽을 수 없으므로 `notify`/`guard` 화면 로그로 대체
- **캘린더는 어느 안에서도 신규 작업.** digitalclock 에는 날짜만 있고 일정이 없다
4. 요구사항 확정 (표시 정보, 갱신 주기, 캘린더 소스, 레이아웃)
5. 플러그인 작성 착수 — `dtdisplay` 구조를 뼈대로

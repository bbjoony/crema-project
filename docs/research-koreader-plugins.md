# KOReader e-ink 시계·캘린더 플러그인 사례 조사

조사일: 2026-08-08

## 조사 목적

크레마 카르타(카르타G 롬 / 안드로이드 4.4.2)를 시계·캘린더 상시 표시 디스플레이로 쓰기 위한 KOReader Lua 플러그인을 직접 작성하기에 앞서, 기존 사례에서 **아키텍처 선택지**와 **플러그인 작성에 필요한 실제 API**를 확보하고, **카르타 고유의 리스크**를 식별한다.

## 요약 (핵심 결론 3가지)

1. **가장 가까운 레퍼런스는 `dtdisplay.koplugin`.** 서버 없이 온디바이스 Lua만으로 전체화면 시계를 그리는 플러그인이며, 파일 4개 규모라 통째로 읽고 출발점으로 삼기 좋다.
2. **아키텍처는 두 갈래로 갈린다** — 온디바이스 렌더링(dtdisplay, calendar.koplugin) vs 서버가 PNG를 만들어 기기가 받아 띄우기(kobo-dashboard, trmnl). 캘린더가 외부 소스(Google Calendar 등)에서 와야 한다면 갈림길이 실제로 발생한다.
3. **최대 리스크는 안드로이드 버전이 아니라 e-ink 리프레시 드라이버다.** 안드로이드 4.4.2는 KOReader 최소 요구(4.3)를 넘겨 문제없다. 반면 안드로이드 e-ink 기기는 전체 리프레시용 표준 API가 없어 KOReader가 벤더별 드라이버를 개별 지원하는데, **크레마 카르타가 지원 목록에 있는지 미확인**이다. 여기서 막히면 잔상(ghosting) 제어가 불가능해 상시 표시용으로서의 가치가 크게 떨어진다.

## 사례

### 1. dtdisplay.koplugin — 전체화면 시계 (온디바이스)

- 저장소: <https://github.com/kktse/dtdisplay.koplugin> (AGPL-3.0)
- 충전 중인 e-ink 기기를 탁상/머리맡 시계로 쓰자는, 이 프로젝트와 사실상 동일한 동기
- 구성: `_meta.lua`, `main.lua`, `displaywidget.lua` — **핵심 로직 파일 2개**
- 진입: 플러그인 → More tools → Time & Day, 화면 아무 곳이나 탭하면 종료
- KOReader 2023.03 "Cherry Blossom"에서 테스트됨 (Kobo Clara 2E, Linux x86 AppImage)
- **날짜/캘린더는 없고 시계+요일만** 표시 → 캘린더는 우리가 직접 얹어야 하는 부분

이 프로젝트의 출발점으로 가장 적합하다.

### 2. calendar.koplugin — iCal 캘린더 (온디바이스)

- 저장소: <https://github.com/omer-faruq/calendar.koplugin> (제작자 omerfaruq)
- Google Calendar 등 **비공개 iCal/ICS URL**을 받아 표시. OAuth·로그인 불필요 → e-ink 기기에 적합
- 일 / 주 / 월 / 아젠다 뷰, 오늘 날짜 강조
- **슬립스크린으로 지정 가능** ← 상시 표시 용도에 직결되는 기능
- 이벤트 캐싱으로 오프라인 동작, 반복 일정 지원
- 한계: 읽기 전용(편집 불가), 타임존을 wall-clock 값으로 표시, 일부 반복 규칙만 처리
- 설치: `koreader/plugins/calendar.koplugin/`에 폴더 복사 + 설정 파일에 iCal URL 기입

캘린더 파트의 참고 구현. 요구사항에 따라서는 **직접 작성 대신 이걸 쓰고 시계만 붙이는 선택지**도 검토할 만하다.

### 3. kobo-dashboard — 서버 렌더 대시보드

- 저장소: <https://github.com/paulakfleck/kobo-dashboard>
- 구조: Docker Compose 3개 서비스(iCal 수집 Python / PNG 생성 Node.js / 웹서버)가 `today.png`를 만들어 서빙, 기기의 Lua 플러그인은 그 이미지를 받아 띄우기만 함
- 표시: 캘린더 일정, 날씨, 이번 달 달력(오늘 강조)
- 갱신 주기 설정 가능(기본 60초). 잦은 갱신 시 전원 연결 필요
- 요구: 상시 구동 서버, 네트워크, 날씨 API

디자인 자유도는 최고지만 **집에 서버를 계속 띄워야 한다.** 토이 프로젝트 규모에는 과할 수 있다.

### 4. trmnl-koreader — 서버 이미지 + 리프레시/절전 설정 참고

- 저장소: <https://github.com/usetrmnl/trmnl-koreader>
- TRMNL 서버가 만든 대시보드 이미지를 KOReader가 받아 표시. 진입은 Tools → TRMNL Display
- 자동 갱신 지원(기본 간격 1800초)
- **e-ink 리프레시 타입을 사용자가 고르게 한다**: `UI (balanced)` / `Full (best quality)` / `Flash UI` / `Partial (fastest)`. 잔상이나 지저분한 화면은 `Full`로 해결하라고 안내
- 절전 대응: Tools → More tools → **Keep alive** 활성화, Settings → Device → **Auto suspend timeout** 비활성화. 별도 wake 로직을 만들지 않고 KOReader 설정에 위임

우리 프로젝트에서 **상시 표시를 어떻게 유지할지**에 대한 가장 실용적인 선례.

## 아키텍처 비교

| | 온디바이스 렌더링 | 서버 렌더 이미지 |
|---|---|---|
| 사례 | dtdisplay, calendar.koplugin | kobo-dashboard, trmnl |
| 추가 인프라 | 없음 | 상시 구동 서버 필요 |
| 레이아웃 자유도 | KOReader 위젯 체계 안에서 | HTML/CSS 자유 |
| 오프라인 | 시계는 완전 동작 | 서버 없으면 갱신 중단 |
| 카르타 부담 | Lua 렌더링 | 이미지 디코딩 + 네트워크 |
| 직접 작성 취지 | 부합 | 플러그인은 얇은 뷰어에 그침 |

"KOReader용 Lua 플러그인을 처음부터 직접 작성한다"는 이 프로젝트의 방향성을 감안하면 **온디바이스 렌더링이 기본 선택지**다. 캘린더 소스를 외부에서 끌어와야 할 때만 서버 방식을 재검토한다.

## 확보한 구체 API 지식

dtdisplay 소스에서 확인한 실제 사용 패턴이다.

### 플러그인 골격

`_meta.lua`:

```lua
local _ = require("gettext")
return {
    name = "dtdisplay",
    fullname = _("Time & Day"),
    description = _([[Shows the current time and date in a fullscreen display.]]),
}
```

`main.lua`:

```lua
local Dispatcher = require("dispatcher")
local DisplayWidget = require("displaywidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local DtDisplay = WidgetContainer:extend {
    name = "dtdisplay",
    config_file = "dtdisplay_config.lua",
    is_doc_only = false,
}

-- init()에서 self.ui.menu:registerToMainMenu(self) 호출 → addToMainMenu() 가 메뉴 구성

function DtDisplay:onDTDisplayLaunch()
    UIManager:show(DisplayWidget:new { props = self.settings })
end
```

- 플러그인 폴더는 `<이름>.koplugin` 규칙, 기기의 `koreader/plugins/` 아래에 둔다
- 메뉴 등록은 `registerToMainMenu` + `addToMainMenu`
- 액션은 `Dispatcher`에 등록해 제스처/단축키에 바인딩 가능

### 위젯과 갱신

- 위젯은 `InputContainer`를 확장하고 `init()`에서 `self[1] = self:render()`
- 주요 모듈: `ffi/blitbuffer`, `frontend/datetime`, `device`, `ui/font`, `ui/widget/container/framecontainer`, `ui/widget/container/inputcontainer`, `ui/uimanager`
- 시각 문자열: `Datetime.secondsToHour(now, true, false)`
- **분 경계에 정확히 맞춰 스케줄링**:

  ```lua
  UIManager:scheduleIn(60 - tonumber(Date("%S")), self.autoRefresh)
  ```

  단순히 60초 간격으로 돌리지 않고 다음 정각 분까지 남은 초를 계산해 드리프트를 없앤다.

### e-ink 리프레시 모드

```lua
UIManager:setDirty("all", "flashpartial")                              -- 초기 표시: 잔상 제거용 플래시
UIManager:setDirty("all", "ui", self.datetime_vertical_group.dimen)    -- 이후 갱신: 영역 한정
```

잔상 누적을 막기 위해 **가끔은 full/flash, 평소에는 partial**로 섞는 것이 정석이다. trmnl이 이 선택을 사용자 설정으로 노출한 것도 같은 맥락.

### 절전 대응

- KOReader의 **Keep alive** (Tools → More tools)
- **Auto suspend timeout** 비활성화 (Settings → Device)
- 커스텀 wake 로직 대신 위 설정에 위임하는 것이 선례

## 카르타 고유 리스크

### 1. 안드로이드 4.4.2 — 문제없음 (확인됨)

F-Droid 기준 **최신 v2026.07.1(2026-08-03)도 "requires Android 4.3 or newer"** 를 유지하고 있다. 4.0–4.2 지원은 v2023.06에서 제거됐지만 4.3이 최소선으로 남았고, 4.4.2는 그 위다.

- 남은 확인 사항: **ABI**. F-Droid 페이지에서 확인한 항목이 arm64-v8a였는데, 카르타 세대 기기는 32비트(armeabi-v7a)일 가능성이 높다. 해당 ABI 빌드를 받아야 한다.

### 2. e-ink 리프레시 드라이버 — 미확인, 최대 리스크

안드로이드에는 e-ink 화면용 표준 API가 없어 벤더마다 방식이 다르고, KOReader는 드라이버별로 **지원 기기 목록**을 관리한다(`refreshU` 등). 목록에 없는 기기는 전체 리프레시 제어가 안 될 수 있다.

- 기기가 지원되는지는 앱 안에서 바로 확인 가능:
  **Tools → More Tools → Developer options → Start compatibility test**
  화면 상단에 `unsupported` 또는 현재 지원 드라이버 설명이 표시된다.
- 미지원일 경우 `android.eink.force.refresh` 브로드캐스트 인텐트가 일부 기기에서 통한다는 보고가 있으나, 기기별 리버스 엔지니어링이 필요하다.
- **영향**: 리프레시 제어가 안 되면 분 단위 갱신에서 잔상이 누적된다. 이 경우 갱신 주기를 늘리거나(예: 5분/10분), 시계 대신 캘린더 위주로 설계를 바꾸는 등 요구사항 자체를 조정해야 한다.

### 3. 개발/디버깅 환경 — 미확인

카르타G 롬에서 개발자 옵션과 ADB 접근이 가능한지 아직 확인되지 않았다. 플러그인 파일을 기기에 넣는 경로(ADB push vs microSD 직접 쓰기)도 이에 따라 달라진다. 16GB microSD가 장착돼 있으므로 카드를 빼서 직접 쓰는 우회로는 있다.

## 다음 단계 (검증 우선순위)

리스크가 큰 것부터 확인한다. 1번이 막히면 설계 자체가 바뀌므로 코드 작성보다 먼저다.

1. **KOReader 설치 및 e-ink 호환성 테스트** — 카르타에 KOReader(맞는 ABI) 설치 → Developer options → Start compatibility test 결과 확인
2. **개발 환경 확인** — 개발자 옵션 / ADB 접근 가능 여부, 플러그인 배포 경로 결정
3. **dtdisplay 실기 구동** — 남의 플러그인을 그대로 올려 카르타에서 도는지 확인. 우리 코드의 문제인지 환경의 문제인지 구분하는 기준점이 된다
4. **요구사항 확정** — 표시 정보(시각/날짜/일정), 갱신 주기, 캘린더 소스(로컬 하드코딩 vs iCal), 레이아웃
5. **플러그인 작성 착수** — dtdisplay 구조를 뼈대로 시작

## 출처

- [kktse/dtdisplay.koplugin](https://github.com/kktse/dtdisplay.koplugin)
- [omer-faruq/calendar.koplugin](https://github.com/omer-faruq/calendar.koplugin) / [MobileRead 소개 스레드](https://www.mobileread.com/forums/showthread.php?t=374361)
- [paulakfleck/kobo-dashboard](https://github.com/paulakfleck/kobo-dashboard)
- [usetrmnl/trmnl-koreader](https://github.com/usetrmnl/trmnl-koreader)
- [KOReader on F-Droid](https://f-droid.org/en/packages/org.koreader.launcher.fdroid/) — 최소 안드로이드 버전 확인
- [koreader/koreader#10614 Android: EOL versions and devices](https://github.com/koreader/koreader/issues/10614)
- [koreader/koreader#8482 Android: support for new e-ink devices](https://github.com/koreader/koreader/issues/8482)
- [koreader/koreader#4517 basic support for android eink refreshes on some rockchip devices](https://github.com/koreader/koreader/pull/4517)
- [KOReader User Guide](https://koreader.rocks/user_guide/)

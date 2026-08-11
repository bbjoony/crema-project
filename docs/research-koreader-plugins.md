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

→ **아래 1-b 로 대체.** `digitalclock.koplugin` 이 더 최신이고 완성도가 높다.

### 1-b. digitalclock.koplugin — 전체화면 시계 (온디바이스) ★ 유력 베이스

- 저장소: <https://github.com/DucNg/digitalclock.koplugin> (**AGPL-3.0**, ★26, 2026-06 갱신)
- 구성: `_meta.lua`, `main.lua` 293줄 — dtdisplay 보다 파일이 적고 최근까지 유지보수됨
- 진입: Tools → More tools → Digital clock. 탭하면 종료. `Dispatcher` 액션도 등록

**그대로 가져올 수 있는 것:**

| 기능 | 구현 |
|---|---|
| 시각/날짜 | 170pt 대형 폰트 + 로케일 인식 날짜 (한국어 대응) |
| **분 경계 정렬** | `UIManager:scheduleIn(61 - os.date("%S"), ...)` — 정각에 갱신 |
| **e-ink 부분 갱신** | 최초 `UIManager:show(self, "full")`, 이후 `setDirty(self, "ui", self.time_dimen)` |
| 배터리 감시 | 2시간 주기, 20% 미만 시 InfoMessage 경고 |

부분 갱신 전략이 특히 값지다. 아래 "리프레시 드라이버" 절의 잔상 누적 우려에 대한
실제 답 — **시각 영역만 `Geom` 으로 지정해 갱신 범위를 좁힌다.**

**카르타에서 안 되는 것 — 하필 핵심 기능이다:**

```lua
function DigitalClock:_pauseAutoSuspend()
    if Device:isCervantes() or Device:isKobo() then ...
    elseif Device:isKindle() then ...
    else logger.warn("pause suspend not supported on this device") end  -- ← 카르타
end
```

카르타는 하드웨어가 Kobo 계열이어도 **OS 가 안드로이드**라 이 분기를 통과하지 못한다.
즉 README 가 내세우는 "일주일 상시 표시"가 우리에게는 빠진다. **상시 표시가 이 프로젝트의
목적 자체이므로, 이것이 현재 최대 리스크다.**

해결은 플러그인이 아니라 KOReader 본체 쪽에 있을 수 있다 — 안드로이드 빌드에
화면 계속 켜기 설정이 내장돼 있다
([timeout_android.lua](https://github.com/koreader/koreader/blob/master/frontend/ui/elements/timeout_android.lua)):

```
설정(톱니) → Screen timeout → "Keep screen on"
```

**→ 카르타에서 선택 가능함을 확인하고 활성화했다 (2026-08-10).** 즉
`android.needsWakelocks()` 가 카르타에서 거짓이며, `AKEEP_SCREEN_ON_ENABLED` 를 쓸 수 있다.
`WRITE_SETTINGS` 권한도 불필요하다 — `canModifyTimeout` 이 `system`/`screenOn` 두 값에
대해서는 권한 검사를 우회한다:

```lua
local function canModifyTimeout(timeout)
    if needs_wakelocks then return false end
    if timeout == system or timeout == screenOn then
        return true                                    -- ← 권한 검사 없이 통과
    else
        return android.settings.hasPermission("settings")
    end
end
```

**상시 표시의 전제가 성립했다.** 플러그인 코드로 wake lock 을 구현할 필요가 없고,
`_pauseAutoSuspend()` 는 카르타에서 그냥 no-op 으로 두면 된다 (이 설정이 대신한다).

남은 확인은 **실제 지속성과 전력**이다. 화면을 계속 켜두면 CPU 가 잠들지 않아 소모가
크다. digitalclock README 의 "일주일" 은 Kobo 기준이며 카르타에는 적용되지 않을 것이다.
상시 표시 용도라면 **USB 전원 연결이 현실적인 전제**다 — USB 데이터는 안 되지만
충전은 되므로 문제없다.

**기타 주의:**

- `PLUGIN_ROOT = "plugins/digitalclock.koplugin/"` 상대 경로 — 안드로이드는 CWD 가
  외부 저장소가 아니므로 사용자 이미지 기능은 동작하지 않고 기본 로고로 폴백할 것이다
- `logger.dbg` 를 쓰는데 안드로이드에서는 logcat 으로 나가 **읽을 수 없다.** 우리
  화면 로그 채널로 바꿔야 한다
- 클래스 정의에 구형 `InputContainer:new{}` 관용구를 쓴다. canary 로 확인한
  `:extend{}` 가 현행 방식
- `is_charging`, `batt_lvl` 등이 `local` 없이 전역으로 새는 곳이 있다
- **AGPL-3.0 이므로 파생물도 AGPL-3.0 + 출처 표기 필요.** 현재 크레마 저장소에는
  라이선스 파일이 없으므로 추가해야 한다

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

> **주의 — 위 선례는 카르타에 그대로 적용되지 않는다 (2026-08-10 소스 확인).**
>
> KOReader 본체의 `keepalive.koplugin` 도 `digitalclock.koplugin` 과 똑같이
> Cervantes/Kobo/Kindle/SDL 만 분기하고 **안드로이드 분기가 없다.** trmnl 이 안내하는
> Keep alive 경로는 Kobo 기준이며 우리에게는 무효다.
>
> ```lua
> if Device:isCervantes() or Device:isKobo() then ...
> elseif Device:isKindle() then ...
> elseif Device:isSDL() then ...
> -- 안드로이드 분기 없음
> ```
>
> 안드로이드에서 절전을 막는 경로는 `PluginShare.pause_auto_suspend` 가 아니라
> **`timeout_android.lua` 의 `AKEEP_SCREEN_ON_ENABLED`** 뿐이다. 안드로이드의 절전은
> OS 가 관리하므로 KOReader 내부 플래그로는 손댈 수 없고, 시스템 설정이나 wake lock 이
>필요하다. 따라서 `설정 → Screen timeout → Keep screen on` 이 **유일한 후보**다.

## 카르타 고유 리스크

### 1. 안드로이드 4.4.2 — 문제없음 (확인됨)

F-Droid 기준 **최신 v2026.07.1(2026-08-03)도 "requires Android 4.3 or newer"** 를 유지하고 있다. 4.0–4.2 지원은 v2023.06에서 제거됐지만 4.3이 최소선으로 남았고, 4.4.2는 그 위다.

- 남은 확인 사항: **ABI**. F-Droid 페이지에서 확인한 항목이 arm64-v8a였는데, 카르타 세대 기기는 32비트(armeabi-v7a)일 가능성이 높다. 해당 ABI 빌드를 받아야 한다.

### 2. e-ink 리프레시 드라이버 — **해소됨 (2026-08-08 실기 확인)**

> 실기 테스트 결과 **Device already supported** / `EPD: freescale` / `Lights: tolino`.
> 카르타는 NTX 보드 + i.MX6 SoloLite(`ntx_6sl`, `imx6`)로 Kobo·Tolino와 같은 계열이라 KOReader가 이미 지원한다.
> 전체 리프레시 제어가 가능하므로 **분 단위 갱신 시계 설계를 그대로 진행**할 수 있고, 덤으로 **프론트라이트 제어**도 쓸 수 있다.
> 아래 원래 분석은 이력으로 남긴다.



안드로이드에는 e-ink 화면용 표준 API가 없어 벤더마다 방식이 다르고, KOReader는 드라이버별로 **지원 기기 목록**을 관리한다(`refreshU` 등). 목록에 없는 기기는 전체 리프레시 제어가 안 될 수 있다.

- 기기가 지원되는지는 앱 안에서 바로 확인 가능:
  **Tools → More Tools → Developer options → Start compatibility test**
  화면 상단에 `unsupported` 또는 현재 지원 드라이버 설명이 표시된다.
- 미지원일 경우 `android.eink.force.refresh` 브로드캐스트 인텐트가 일부 기기에서 통한다는 보고가 있으나, 기기별 리버스 엔지니어링이 필요하다.
- **영향**: 리프레시 제어가 안 되면 분 단위 갱신에서 잔상이 누적된다. 이 경우 갱신 주기를 늘리거나(예: 5분/10분), 시계 대신 캘린더 위주로 설계를 바꾸는 등 요구사항 자체를 조정해야 한다.

### 3. 개발/디버깅 환경 — **해소됨 (2026-08-10 실기 확인)**

> **ADB 는 불가, 배포 경로는 확보.** 카르타G 롬은 자체 설정 화면을 쓰고 빌드 번호 항목이
> 없어 개발자 옵션을 켤 수 없다. 맥 USB 연결은 기기 열거까지는 되지만(`0x1F85:0x6155`)
> 데이터 인터페이스가 붙지 않아 adb·마운트 모두 실패한다.
>
> 대신 **KOReader 파일 브라우저**로 배포가 가능하다. 사용자 플러그인 경로
> `/storage/emulated/0/koreader/plugins/` 가 존재하며(현재 비어 있음, 정상),
> Send Anywhere 로 받은 폴더를 브라우저 안에서 복사·붙여넣기 하면 된다.
> **microSD 를 뽑는 우회로도, 루팅도 필요 없다.** 상세는 CLAUDE.md 참조.
>
> 남는 제약은 **로그캣 부재**다. 실패 원인을 화면에 보이는 것으로만 좁혀야 하므로
> 플러그인은 작게 시작해 단계적으로 키운다.

## 다음 단계 (검증 우선순위)

리스크가 큰 것부터 확인한다. 1번이 막히면 설계 자체가 바뀌므로 코드 작성보다 먼저다.

1. ~~**KOReader 설치 및 e-ink 호환성 테스트**~~ — 완료 (2026-08-08)
2. ~~**개발 환경 확인**~~ — 완료 (2026-08-10). ADB 불가, 배포는 KOReader 파일 브라우저
3. ~~**최소 플러그인(canary) 실기 구동**~~ — 완료 (2026-08-10). 로드·화면 로그 채널 모두 성공. Lua 5.1 / v2026.07.1 / `os.date` 로컬 시각 정상
4. ~~**안드로이드 절전 억제 확인**~~ — **해소 (2026-08-10).** `설정 → Screen timeout → Keep screen on` 활성화 완료. 위 1-b 절 참조
5. **digitalclock.koplugin 재사용 결정** — **C안 진행 중.** 수정 없이 설치해 실측한 뒤 A(기법만 참조) / B(포크) 를 정한다. 설치 전 사전 점검 프로브는 `cremaclock` 메뉴에 작성 완료 (2026-08-11), 실기 실행 대기
6. **요구사항 확정** — 표시 정보(시각/날짜/일정), 갱신 주기, 캘린더 소스(로컬 하드코딩 vs iCal), 레이아웃
7. **플러그인 작성 착수** — digitalclock 구조를 뼈대로 시작

## 출처

- [DucNg/digitalclock.koplugin](https://github.com/DucNg/digitalclock.koplugin) — 유력 베이스 (AGPL-3.0)
- [kktse/dtdisplay.koplugin](https://github.com/kktse/dtdisplay.koplugin)
- [KOReader timeout_android.lua](https://github.com/koreader/koreader/blob/master/frontend/ui/elements/timeout_android.lua) — 안드로이드 화면 계속 켜기 / needsWakelocks 분기
- [omer-faruq/calendar.koplugin](https://github.com/omer-faruq/calendar.koplugin) / [MobileRead 소개 스레드](https://www.mobileread.com/forums/showthread.php?t=374361)
- [paulakfleck/kobo-dashboard](https://github.com/paulakfleck/kobo-dashboard)
- [usetrmnl/trmnl-koreader](https://github.com/usetrmnl/trmnl-koreader)
- [KOReader on F-Droid](https://f-droid.org/en/packages/org.koreader.launcher.fdroid/) — 최소 안드로이드 버전 확인
- [koreader/koreader#10614 Android: EOL versions and devices](https://github.com/koreader/koreader/issues/10614)
- [koreader/koreader#8482 Android: support for new e-ink devices](https://github.com/koreader/koreader/issues/8482)
- [koreader/koreader#4517 basic support for android eink refreshes on some rockchip devices](https://github.com/koreader/koreader/pull/4517)
- [KOReader User Guide](https://koreader.rocks/user_guide/)

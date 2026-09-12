--[[--
Crema Display — 크레마 카르타 상시 표시용 시계.

**[DucNg/digitalclock.koplugin](https://github.com/DucNg/digitalclock.koplugin) 의 포크다.**
원본은 AGPL-3.0 이며 이 파일과 저장소 전체가 같은 라이선스를 따른다. 전문은 루트 `LICENSE`.

카르타에 맞춰 원본에서 바꾼 것 (배경은 저장소 CLAUDE.md):

1. **이미지 경로를 절대 경로로.** 안드로이드는 CWD 가 앱 전용 디렉터리라 원본의
   `PLUGIN_ROOT = "plugins/digitalclock.koplugin/"` 상대 경로가 외부 저장소에 닿지
   않는다. 실기에서 사용자 이미지가 안 열리고 폴백 로고로 떨어지는 것을 확인했다.
2. **이미지 크기 제한.** 원본은 원본 픽셀 그대로 그린다. 작게 넣고 싶으므로 상자를
   지정해 비율을 유지한 채 줄인다. 원본 README 도 큰 비 SVG 이미지는 KOReader 를
   죽일 수 있다고 경고한다.
3. **부분 갱신 영역을 계산으로.** 원본은 y 를 100 으로 하드코딩했는데, 실제 배치는
   `CenterContainer` 세로 중앙 정렬이라 그 값은 원본 이미지 크기일 때만 맞는다.
   이미지 크기를 바꾸면 갱신 영역이 어긋나 **분이 바뀌어도 옛 숫자가 남는다.**
   그래서 실제 배치와 같은 식으로 위치를 구한다. 2번 변경의 전제 조건이다.
   더불어 `FrameContainer` 의 테두리·여백을 0 으로 명시했다. 기본값이 0 이 아니라
   내용물을 밀어내므로, 그대로 두면 이 계산이 그만큼 어긋난다.
4. **날짜를 한국어 어순으로.** 원본 템플릿은 `%1 %2 %3 %4` 라 토큰만 한글이 되고
   어순은 영어를 따른다 (`화요일 8월 11 2026`). `2026년 8월 11일 화요일` 로 바꿨다.
5. **배터리 감시 제거.** 상시 USB 전원을 전제로 하므로 항상 충전 중이고, 원본은 그때
   2시간마다 `⚡100%` 알림을 timeout 2시간으로 띄운다 — 벽시계 화면에 상주해버린다.
6. **절전 억제 코드 제거.** 원본의 `_pauseAutoSuspend()` 는 Kobo/Kindle 분기뿐이라
   안드로이드인 카르타에서는 경고만 남기고 아무 일도 하지 않는다. 카르타는 KOReader
   본체 설정 `Screen timeout → Keep screen on` 이 그 역할을 대신한다.
7. 식별자·메뉴 키를 `crema_display` 로 바꿨다. 원본을 기기에 남겨둔 채 이걸 설치해도
   메뉴 항목과 Dispatcher 액션이 충돌하지 않는다.
8. **날짜 갱신을 정확한 자정에.** 원본 `_getNextDateRefreshInSeconds()` 는 시(hour)만
   보고 분·초를 버려서 날짜가 최대 59분 늦게 바뀐다. 상시 표시용이라 자정을 넘기는
   것이 정상 동작이므로 매일 눈에 띈다.
9. **재개 시 스케줄 중복 방지.** 원본 `onResume` 은 갱신 함수를 바로 호출하는데, 그
   함수들이 내부에서 다시 `scheduleIn` 을 걸기 때문에 예약이 살아 있는 상태로 재개하면
   스케줄이 한 겹씩 누적된다. 상시 표시용은 재개를 여러 번 겪으므로 방어해 둔다.
]]

local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local datetime = require("frontend/datetime")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ImageWidget = require("ui/widget/imagewidget")
local Input = Device.input
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = Device.screen
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

-- 원본과 달리 절대 경로다. 상대 경로는 안드로이드에서 외부 저장소에 닿지 않는다.
local PLUGIN_ROOT = DataStorage:getDataDir() .. "/plugins/cremadisplay.koplugin/"

-- 이미지를 넣을 상자. 비율을 유지한 채 이 안에 들어가도록 줄인다.
-- 상한은 788 이다 — 화면 높이 1448 에서 시각(423) + 날짜(107) + 간격(130) 을 뺀 값.
-- 600 은 위아래로 94px 씩 여백을 남기는 크기다. 키우려면 여기만 고치면 된다.
local IMAGE_BOX = 600

-- image.png 는 571x600 이고, 오른쪽 85px 은 의도적으로 비워 둔 투명 여백이다.
-- 캐릭터가 왼쪽으로 팔을 뻗고 있어서 그림을 그대로 중앙 정렬하면 몸통이 오른쪽으로
-- 63px 치우쳐 보였다. 여백을 덧대 잉크 전체의 무게중심을 캔버스 중앙에 맞춘 것이다.
-- 세로가 600 으로 가로보다 길어 축소 배율은 항상 세로가 결정한다.
--
-- 이 PNG 는 RGB 가 전부 순수한 검정이고 농담이 알파 채널에만 담겨 있다. 원본은 모자
-- 상단의 알파가 100 안팎이라 e-ink 에서 외곽선이 희미했으므로, 알파만 보정해 선을
-- 진하고 굵게 만들었다. 배경 투명도는 그대로 유지된다.
-- 이미지를 교체하면 여백 보정과 선 보정이 모두 사라지므로 새 그림에 맞춰 다시 해야 한다.

-- 시각과 날짜 사이 간격. 원본 값 그대로.
local SEPARATOR_HEIGHT = 130

local CremaDisplay = InputContainer:extend{
    name = "CremaDisplay",
    is_doc_only = false,
    dimen = Screen:getSize(),
}

function CremaDisplay:onDispatcherRegisterActions()
    Dispatcher:registerAction("crema_display",
        {category="none", event="ShowCremaDisplay", title=_("Crema display"), general=true,})
end

function CremaDisplay:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)

    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight(),
                }
            }
        }
    end
end

--- `2026년 8월 11일 화요일`.
-- 월은 번역 테이블 대신 숫자로 뽑는다 — `longMonthTranslation` 이 `8월` 을 돌려주므로
-- 거기에 `월` 을 또 붙이면 `8월월` 이 된다. `tonumber` 로 앞의 0 도 떨군다.
-- 요일만 번역 테이블을 탄다. 기기 UI 가 한국어면 `화요일` 이 나오는 것을 실기에서 확인했다.
function CremaDisplay:_getDateString()
    local wday = datetime.shortDayOfWeekToLongTranslation[os.date("%a")] or os.date("%a")

    return ("%d년 %d월 %d일 %s"):format(
        tonumber(os.date("%Y")),
        tonumber(os.date("%m")),
        tonumber(os.date("%d")),
        wday)
end

--- 사용자 이미지를 찾고, 없으면 KOReader 로고로 떨어진다.
-- 폴백만 상대 경로인 것은 의도한 것이다 — KOReader 본체 에셋은 CWD 아래에 풀려 있어
-- 이 경로로 열리는 것을 실기에서 확인했다.
function CremaDisplay:_getFileName()
    local supported_files = {"png", "svg", "jpg", "jpeg"}

    for _, extension in ipairs(supported_files) do
        local filename = PLUGIN_ROOT .. "image." .. extension
        local f = io.open(filename, "r")
        if f ~= nil then
            io.close(f)
            return filename
        end
    end

    return "resources/koreader.svg"
end

--- 다음 자정까지 남은 초. 자정이 지난 1초 뒤에 깨어난다.
-- 원본은 `(24 - %H) * 3600` 으로 시(hour)만 보고 분·초를 버렸다. 23시 30분에 켜면
-- 3600초 뒤인 **00시 30분**에야 날짜가 바뀐다 — 최대 59분 늦는다.
function CremaDisplay:_getNextDateRefreshInSeconds()
    local now = os.date("*t")

    return 86400 - (now.hour * 3600 + now.min * 60 + now.sec) + 1
end

function CremaDisplay:addToMainMenu(menu_items)
    menu_items.crema_display = {
        text = _("Crema display"),
        sorting_hint = "more_tools",
        callback = function()
            CremaDisplay:showClock()
        end
    }
end

function CremaDisplay:showClock()
    self.time_widget = TextWidget:new{
        text = datetime.secondsToHour(os.time()),
        face = Font:getFace("cfont", 170)
    }

    self.separator = VerticalSpan:new{width = SEPARATOR_HEIGHT}

    self.date_widget = TextWidget:new{
        text = self:_getDateString(),
        face = Font:getFace("cfont", 40)
    }

    -- scale_factor = 0 은 width/height 상자에 비율을 유지한 채 맞추라는 뜻이다.
    self.image_widget = ImageWidget:new{
        file = CremaDisplay:_getFileName(),
        alpha = true,
        width = IMAGE_BOX,
        height = IMAGE_BOX,
        scale_factor = 0,
    }

    self.vertical_container = VerticalGroup:new{
        self.time_widget,
        self.date_widget,
        self.separator,
        self.image_widget
    }

    self.centered_container = CenterContainer:new{
        self.vertical_container,
        dimen = self.dimen
    }

    -- 테두리·여백을 명시적으로 0 으로 둔다. FrameContainer 의 기본값은
    -- bordersize = Size.border.window, padding = Size.padding.default 이라
    -- 원본처럼 background 만 주면 화면 가장자리에 테두리가 생기고, 그만큼 안쪽
    -- 내용물이 밀려 아래 중앙 정렬 계산이 어긋난다. 벽시계에 테두리는 불필요하다.
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        self.centered_container
    }

    -- 부분 갱신 영역. 원본은 y 를 100 으로 하드코딩했지만 배치는 세로 중앙 정렬이므로,
    -- 이미지 크기가 바뀌면 덩어리 전체가 위아래로 움직인다. CenterContainer 와 같은
    -- 식으로 윗변을 구해야 갱신 영역이 실제 글자 위에 얹힌다.
    local time_widget_height = self.time_widget:getSize().h
    local date_widget_height = self.date_widget:getSize().h
    local content_height = time_widget_height + date_widget_height
        + SEPARATOR_HEIGHT + self.image_widget:getSize().h
    local top_y = math.floor((self.dimen.h - content_height) / 2)

    self.time_dimen = Geom:new{
        x = 0,
        y = top_y,
        w = self.dimen.w,
        h = time_widget_height,
    }

    self.date_dimen = Geom:new{
        x = 0,
        y = top_y + time_widget_height,
        w = self.dimen.w,
        h = date_widget_height,
    }

    UIManager:show(self, "full")

    self:setupAutoRefreshTime()
end

function CremaDisplay:setupAutoRefreshTime()
    -- 분 경계에 맞춰 갱신한다. 61 - 초 이므로 다음 분이 시작되고 1초 뒤에 깨어난다.
    self.autoRefreshTime = function()
        self.time_widget:setText(datetime.secondsToHour(os.time()))
        self.vertical_container:free()

        UIManager:setDirty(self, "ui", self.time_dimen)

        UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.autoRefreshTime)
    end

    self.autoRefreshDate = function()
        self.date_widget:setText(self:_getDateString())
        self.vertical_container:free()

        UIManager:setDirty(self, "ui", self.date_dimen)

        UIManager:scheduleIn(self:_getNextDateRefreshInSeconds(), self.autoRefreshDate)
    end

    self.onCloseWidget = function()
        UIManager:unschedule(self.autoRefreshTime)
        UIManager:unschedule(self.autoRefreshDate)
    end
    self.onSuspend = function()
        UIManager:unschedule(self.autoRefreshTime)
        UIManager:unschedule(self.autoRefreshDate)
    end
    self.onResume = function()
        -- 두 갱신 함수는 내부에서 다시 scheduleIn 을 걸기 때문에, 이미 예약이 살아
        -- 있는 상태에서 호출하면 스케줄이 한 겹 더 쌓인다. `onSuspend` 없이
        -- `onResume` 만 도달하는 흐름에서 재개할 때마다 누적되므로, 흐름에 기대지
        -- 않고 여기서 먼저 걷어낸다.
        UIManager:unschedule(self.autoRefreshTime)
        UIManager:unschedule(self.autoRefreshDate)

        self.autoRefreshTime()
        self.autoRefreshDate()
    end

    UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.autoRefreshTime)
    UIManager:scheduleIn(self:_getNextDateRefreshInSeconds(), self.autoRefreshDate)
end

function CremaDisplay:onTapClose()
    UIManager:close(self)
end
CremaDisplay.onAnyKeyPressed = CremaDisplay.onTapClose

function CremaDisplay:onShowCremaDisplay()
    CremaDisplay:showClock()
end

return CremaDisplay

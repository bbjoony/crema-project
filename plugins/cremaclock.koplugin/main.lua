--[[--
Crema Clock — 크레마 카르타용 시계·캘린더 e-ink 디스플레이 플러그인.

**현재 단계: canary + digitalclock 사전 점검.**

카르타는 adb 가 막혀 있어 logcat 을 읽을 수 없고, 안드로이드 빌드는 crash.log 도
남기지 않는다 (자세한 배경은 저장소 CLAUDE.md 참조). 따라서 이 플러그인은 두 가지를
검증하는 것으로 시작했다.

1. **로드 검증** — init/메뉴 등록 경로에는 실패할 만한 호출을 두지 않는다.
   메뉴에 항목이 뜨면 배포 경로와 플러그인 골격이 정상이라는 뜻이다.
2. **로그 채널 검증** — 앞으로 쓸 디버깅 수단은 화면 표시뿐이다. 콜백에서 환경 정보를
   긁어 InfoMessage 로 띄워보고, 그 과정 전체를 pcall 로 감싼다.

이 구조가 중요한 이유: 위험한 코드가 init 에 있으면 로드가 실패하고, 그러면 화면에
아무것도 못 띄우므로 신호가 "메뉴에 안 뜬다" 하나로 뭉개진다. 위험한 일은 전부
콜백 안쪽 pcall 로 밀어넣어야 실패해도 원인을 읽을 수 있다.

둘 다 2026-08-10 실기에서 통과했다. 여기에 세 번째 역할이 붙었다.

3. **digitalclock 사전 점검** — `digitalclock.koplugin` 을 수정 없이 올려 상시 표시를
   실측하기로 했다 (C안). 그런데 그 플러그인은 최상단에서 `require("frontend/datetime")`
   같은 호출을 하고 상대 경로로 이미지를 열기 때문에, 카르타에서 실패하면 위와 똑같이
   "메뉴에 안 뜬다" 로만 나타난다. **남의 코드는 pcall 로 감쌀 수 없으므로, 그 코드가
   의존하는 것들을 여기서 미리 대신 확인한다.** digitalclock 자체는 손대지 않는다.
]]

local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local CremaClock = WidgetContainer:extend{
    name = "cremaclock",
    is_doc_only = false,
}

--- 오류 메시지를 한 줄로 눌러 화면에 들어갈 길이로 자른다.
-- require 실패 메시지는 탐색한 경로를 모두 늘어놓아 InfoMessage 를 넘치게 하는데,
-- 그 경로 목록 자체가 정보이므로 버리지 않고 앞부분만 남긴다.
-- @string err
-- @int limit 남길 바이트 수
local function shorten(err, limit)
    local text = tostring(err):gsub("%s+", " ")
    if #text > limit then
        text = text:sub(1, limit) .. "..."
    end
    return text
end

--- 프로브 여러 개를 각각 pcall 로 감싸 한 번에 수집한다.
-- 개별로 감싸는 이유: 한 항목이 이 KOReader 버전에 없는 API 여도 나머지는 계속
-- 모아야 한다. 기기 왕복이 비싸므로 한 번에 최대한 많이 알아내는 것이 목적이다.
-- @tab items {라벨, 함수} 쌍의 배열
-- @treturn string 줄바꿈으로 이어붙인 결과
local function collect(items)
    local lines = {}
    for _, item in ipairs(items) do
        local ok, value = pcall(item[2])
        table.insert(lines, ("%s: %s"):format(
            item[1], ok and tostring(value) or ("ERR " .. shorten(value, 90))))
    end
    return table.concat(lines, "\n")
end

--- 상대 경로가 실제로 열리는지 본다. 존재 여부가 아니라 **CWD 기준으로 열리는지**가
-- 궁금한 것이므로, lfs 로 확인하지 않고 digitalclock 과 같은 io.open 으로 확인한다.
local function opens(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return "opens"
    end
    return "MISSING"
end

--- 폰트 크기가 카르타 화면에 들어가는지 보려고 실제 위젯을 만들어 높이를 잰다.
-- 만든 위젯은 바로 free 한다 — 화면에 올리지 않으므로 남겨둘 이유가 없다.
local function textHeight(size, text)
    local Font = require("ui/font")
    local TextWidget = require("ui/widget/textwidget")
    local widget = TextWidget:new{ text = text, face = Font:getFace("cfont", size) }
    local height = widget:getSize().h
    widget:free()
    return height
end

--- 화면 로그 채널. logcat·crash.log 를 못 쓰므로 이게 유일한 출력 수단이다.
-- @string text 표시할 내용
-- @int timeout 초. nil 이면 탭할 때까지 유지 (오류 표시용)
function CremaClock:notify(text, timeout)
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = timeout,
    })
end

--- 위험한 작업을 감싸 실패해도 원인을 화면에서 읽을 수 있게 한다.
-- @string label 실패 시 어느 단계였는지 알려줄 이름
-- @func fn
-- @return ok, result
function CremaClock:guard(label, fn)
    local ok, result = pcall(fn)
    if not ok then
        self:notify(("ERR [%s]\n%s"):format(label, tostring(result)))
    end
    return ok, result
end

--- Lua 환경을 탐색해 canary 로 확인하고 싶은 정보를 모은다.
function CremaClock:probeEnvironment()
    return collect{
        {"lua", function() return _VERSION end},
        {"koreader", function() return require("version"):getCurrentRevision() end},
        {"model", function() return require("device").model end},
        {"datadir", function() return require("datastorage"):getDataDir() end},
        {"time", function() return os.date("%Y-%m-%d %H:%M:%S") end},
    }
end

--- digitalclock 이 로드·표시 시점에 의존하는 것들을 대신 확인한다.
-- 여기서 걸리는 항목이 곧 "설치했는데 메뉴에 안 뜬다" 또는 "탭하니 죽는다" 의 원인이다.
function CremaClock:probeDigitalClockDeps()
    return collect{
        -- digitalclock main.lua 최상단의 require 들. 하나라도 실패하면 플러그인이 아예
        -- 로드되지 않는다. frontend/ 접두사가 붙은 첫 항목이 가장 의심스럽다 —
        -- KOReader 는 package.path 에 frontend/ 를 이미 넣으므로 보통 접두사 없이 쓴다.
        {"req frontend/datetime", function() return type(require("frontend/datetime")) end},
        {"req datetime", function() return type(require("datetime")) end},
        {"req pluginshare", function() return type(require("pluginshare")) end},
        {"req dispatcher", function() return type(require("dispatcher")) end},
        {"req imagewidget", function() return type(require("ui/widget/imagewidget")) end},

        -- 상대 경로 해석. digitalclock 은 사용자 이미지(`PLUGIN_ROOT .. "image.png"`)와
        -- 폴백 로고(`resources/koreader.svg`)를 **모두** CWD 기준 상대 경로로 연다.
        -- 안드로이드에서 CWD 가 어디인지가 갈림길이다.
        {"cwd", function() return require("libs/libkoreader-lfs").currentdir() end},
        {"fallback logo", function() return opens("resources/koreader.svg") end},
        -- 기준점. 이건 지금 확실히 설치돼 있으므로, MISSING 이면 원인은 CWD 하나뿐이다.
        -- 아래 digitalclock 항목의 MISSING 을 "CWD 틀림" 과 "아직 설치 안 함" 으로 가른다.
        {"self via relpath", function() return opens("plugins/cremaclock.koplugin/main.lua") end},
        {"PLUGIN_ROOT", function() return opens("plugins/digitalclock.koplugin/main.lua") end},

        -- 날짜 문자열. os.date 의 요일·월 이름을 영어 약어 키로 조회하는데, 기기 로케일이
        -- 한국어라 키가 달라지면 nil 이 템플릿으로 넘어가 표시 시점에 죽는다.
        {"os.date a/B", function() return os.date("%a") .. " / " .. os.date("%B") end},
        {"wday lookup", function()
            return tostring(require("datetime").shortDayOfWeekToLongTranslation[os.date("%a")])
        end},
        {"month lookup", function()
            return tostring(require("datetime").longMonthTranslation[os.date("%B")])
        end},
    }
end

--- 화면 크기와 폰트 높이. digitalclock 의 레이아웃이 카르타에 들어가는지 미리 계산한다.
-- digitalclock 은 시각 170pt + 날짜 40pt + 여백 130 + 이미지를 세로로 쌓고,
-- 부분갱신 Geom 의 y 를 100 으로 하드코딩한다. 값을 알면 잘림 여부를 눈으로 보기 전에 안다.
function CremaClock:probeLayout()
    local Device = require("device")
    return collect{
        {"screen", function()
            local size = Device.screen:getSize()
            return ("%dx%d"):format(size.w, size.h)
        end},
        {"dpi", function() return Device.screen:getDPI() end},
        {"touch", function() return Device:isTouchDevice() end},
        {"keys", function() return Device:hasKeys() end},
        {"battery", function() return Device:hasBattery() end},
        {"aux battery", function() return Device:hasAuxBattery() end},
        {"time 170pt h", function() return textHeight(170, "00:00") end},
        {"date 40pt h", function() return textHeight(40, "Tuesday August 11 2026") end},
    }
end

--- 상시 표시 실측용 스냅샷. 시작·종료 시점에 이걸 읽어 적어두면 소모율을 계산할 수 있다.
-- 배터리 잔량을 보려고 KOReader 를 나가면 실측이 끊기므로 플러그인 안에서 읽는다.
function CremaClock:probeBattery()
    return collect{
        {"time", function() return os.date("%Y-%m-%d %H:%M:%S") end},
        {"capacity", function()
            return require("device"):getPowerDevice():getCapacity() .. "%"
        end},
        {"charging", function()
            return require("device"):getPowerDevice():isCharging()
        end},
        -- digitalclock 실행 중에 읽으면 절전 억제가 실제로 걸렸는지 알 수 있다.
        {"pause_auto_suspend", function() return require("pluginshare").pause_auto_suspend end},
    }
end

--- 프로브 목록을 돌려 화면에 띄운다. timeout 없이 띄워 탭할 때까지 읽을 수 있게 한다.
function CremaClock:showProbe(label, fn)
    local ok, info = self:guard(label, fn)
    if ok then
        self:notify(("[%s]\n\n%s"):format(label, info))
    end
end

function CremaClock:init()
    -- 실패할 여지가 있는 것은 여기에 두지 않는다. 위 주석 참조.
    self.ui.menu:registerToMainMenu(self)
end

function CremaClock:addToMainMenu(menu_items)
    menu_items.cremaclock = {
        -- e-ink 호환성 테스트를 돌렸던 Tools → More tools 아래에 붙는다.
        sorting_hint = "more_tools",
        text = _("Crema Clock (canary)"),
        sub_item_table = {
            {
                text = _("환경 프로브"),
                keep_menu_open = true,
                callback = function()
                    self:showProbe("env", function() return self:probeEnvironment() end)
                end,
            },
            {
                text = _("digitalclock 의존성 점검"),
                keep_menu_open = true,
                callback = function()
                    self:showProbe("dc deps", function() return self:probeDigitalClockDeps() end)
                end,
            },
            {
                text = _("화면·레이아웃"),
                keep_menu_open = true,
                callback = function()
                    self:showProbe("layout", function() return self:probeLayout() end)
                end,
            },
            {
                text = _("배터리 스냅샷"),
                keep_menu_open = true,
                callback = function()
                    self:showProbe("battery", function() return self:probeBattery() end)
                end,
            },
        },
    }
end

return CremaClock

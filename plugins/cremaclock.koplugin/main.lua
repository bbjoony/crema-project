--[[--
Crema Clock — 크레마 카르타용 시계·캘린더 e-ink 디스플레이 플러그인.

**현재 단계: canary.**

카르타는 adb 가 막혀 있어 logcat 을 읽을 수 없고, 안드로이드 빌드는 crash.log 도
남기지 않는다 (자세한 배경은 저장소 CLAUDE.md 참조). 따라서 이 플러그인은 두 가지를
검증하는 것으로 시작한다.

1. **로드 검증** — init/메뉴 등록 경로에는 실패할 만한 호출을 두지 않는다.
   메뉴에 항목이 뜨면 배포 경로와 플러그인 골격이 정상이라는 뜻이다.
2. **로그 채널 검증** — 앞으로 쓸 디버깅 수단은 화면 표시뿐이다. 콜백에서 환경 정보를
   긁어 InfoMessage 로 띄워보고, 그 과정 전체를 pcall 로 감싼다.

이 구조가 중요한 이유: 위험한 코드가 init 에 있으면 로드가 실패하고, 그러면 화면에
아무것도 못 띄우므로 신호가 "메뉴에 안 뜬다" 하나로 뭉개진다. 위험한 일은 전부
콜백 안쪽 pcall 로 밀어넣어야 실패해도 원인을 읽을 수 있다.
]]

local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local CremaClock = WidgetContainer:extend{
    name = "cremaclock",
    is_doc_only = false,
}

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
-- 각 항목을 개별 pcall 로 감싸는 이유: 한 항목이 이 KOReader 버전에서 없는 API 여도
-- 나머지는 계속 수집해야 한다. 한 번의 기기 왕복에서 최대한 많이 알아내는 것이 목적.
function CremaClock:probeEnvironment()
    local lines = {}

    local function probe(label, fn)
        local ok, value = pcall(fn)
        table.insert(lines, ("%s: %s"):format(label, ok and tostring(value) or "n/a"))
    end

    probe("lua", function() return _VERSION end)
    probe("koreader", function() return require("version"):getCurrentRevision() end)
    probe("model", function() return require("device").model end)
    probe("datadir", function() return require("datastorage"):getDataDir() end)
    probe("time", function() return os.date("%Y-%m-%d %H:%M:%S") end)

    return table.concat(lines, "\n")
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
        callback = function()
            local ok, info = self:guard("probe", function()
                return self:probeEnvironment()
            end)
            if ok then
                self:notify("CANARY OK\n\n" .. info)
            end
        end,
    }
end

return CremaClock

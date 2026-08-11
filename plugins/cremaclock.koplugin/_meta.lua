local _ = require("gettext")

return {
    name = "cremaclock",
    fullname = _("Crema Clock"),
    description = _([[
크레마 카르타를 시계·캘린더 상시 표시용 e-ink 디스플레이로 쓰기 위한 플러그인.

현재는 canary 단계로, 플러그인 로딩과 화면 로그 채널이 동작하는지 확인하고,
digitalclock 을 설치하기 전에 그것이 의존하는 것들을 대신 점검하는 역할만 한다.]]),
}

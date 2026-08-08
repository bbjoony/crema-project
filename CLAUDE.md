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
전체 리프레시 제어와 프론트라이트 제어 모두 KOReader가 지원한다. NTX 보드 + i.MX6 SoloLite 조합으로, Kobo·Tolino 기기와 같은 하드웨어 계열이다.

설치본: `koreader-android-arm-v2026.07.1.apk` (armeabi-v7a). 설치 경로는 크레마 **열린서재 → `+`**.

## 개발 시 유의사항

- 타깃이 **안드로이드 4.4.2 (KitKat)** 로 매우 구형이다. 최신 API·툴체인 가정 금지. KOReader 및 Lua 환경 제약을 항상 고려할 것.
- 개발/디버깅 환경(개발자 옵션, ADB 접근 여부)은 **아직 미확인**. 관련 작업 전 확인 필요.

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

1. **KOReader 설치 + e-ink 호환성 테스트** (Tools → More Tools → Developer options → Start compatibility test) — 리프레시 드라이버 미지원이면 설계가 바뀌므로 최우선
2. 개발/디버깅 환경 확인 (개발자 옵션, ADB) 및 플러그인 배포 경로 결정
3. `dtdisplay.koplugin` 실기 구동 — 환경 문제와 우리 코드 문제를 구분할 기준점
4. 요구사항 확정 (표시 정보, 갱신 주기, 캘린더 소스, 레이아웃)
5. 플러그인 작성 착수 — `dtdisplay` 구조를 뼈대로

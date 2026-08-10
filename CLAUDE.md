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

## 개발 시 유의사항

- 타깃이 **안드로이드 4.4.2 (KitKat)** 로 매우 구형이다. 최신 API·툴체인 가정 금지. KOReader 및 Lua 환경 제약을 항상 고려할 것.
- **디버깅 수단이 제한적이다.** adb 로그캣을 못 쓰므로 플러그인 오류는 기기 화면에 뜨는 것만 보고 판단해야 한다. 실패 시 원인 범위를 좁히기 어렵기 때문에, 코드를 크게 쓰지 말고 **작은 단위로 올려 확인하며 키워 나갈 것.**

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
3. **최소 플러그인 1개 실기 구동** — 메뉴에 항목만 띄우는 수준의 canary. 배포 경로와 플러그인 로딩이 실제로 도는지 확인하는 기준점 (`dtdisplay.koplugin` 는 그다음)
4. 요구사항 확정 (표시 정보, 갱신 주기, 캘린더 소스, 레이아웃)
5. 플러그인 작성 착수 — `dtdisplay` 구조를 뼈대로

# Claude 내 컴퓨터 작업 유지 키트

Claude(Cowork, Claude Code)가 내 PC에서 하는 작업이 **멈추지 않고**, 새 대화를 열어도 **이어서 진행되고**, 결과물이 **사라지지 않도록** 설정하는 키트입니다.

- 대상 작업 폴더: `C:\utility\Cowork task Claude setup 2026-10-05`
- 백업 폴더: `C:\utility\Claude-backup`
- Windows 10/11, 보통 관리자 권한 없이 실행됩니다 (안 되는 단계가 있으면 화면에 방법이 나옵니다)

## 1. 작업이 끊기는 이유와 이 키트의 해결책

| 끊기는 이유 | 해결 방법 | 키트가 하는 일 |
|---|---|---|
| PC가 절전 모드로 들어가면 진행 중인 작업과 Cowork 예약 작업이 멈춤 | PC를 깨어 있게 유지 | 전원 연결 시 절전·최대 절전 끄기 (배터리 설정은 그대로). 원래 값은 저장해 두었다가 되돌릴 수 있음 |
| Claude 데스크톱 앱이 꺼져 있으면 Cowork 예약 작업이 실행되지 않음 | 로그인하면 앱이 자동으로 켜지게 | 시작프로그램에 Claude 앱 바로가기 등록 |
| 새 대화를 열면 Claude는 이전 대화 내용을 모름 | 작업 규칙과 진행 기록을 **폴더 안 파일**로 남김 | `CLAUDE.md`(작업 규칙), `작업일지.md`(한 일/다음 할 일) 생성 |
| 파일을 실수로 덮어쓰거나 지움 | 매일 자동 백업 | 매일 23:00 작업 폴더를 zip으로 백업, 최근 14개 보관. PC가 꺼져 있어 놓친 백업은 다음에 켜질 때 실행 |
| 밖에 있을 때 이어서 하고 싶음 | Remote Control | `Claude-remote-control.cmd` 실행 → 휴대폰/웹의 Claude 앱에서 이 PC의 세션을 이어서 사용 |

핵심은 **"Claude의 기억은 대화가 아니라 폴더에 둔다"** 입니다. 대화는 끝나도 `CLAUDE.md`와 `작업일지.md`는 남으므로, 어떤 대화에서든 그 파일을 읽으면 같은 맥락에서 이어갈 수 있습니다.

## 2. 실행 방법 (처음 한 번)

이 키트는 **내 PC에서** 실행해야 합니다. 아래 셋 중 편한 방법을 고르세요.

### 방법 A: PowerShell (Git이 설치되어 있을 때)

```powershell
cd C:\utility
git clone -b claude/claude-work-setup-maintain-73kxlb https://github.com/purmhyun/K.koreana claude-keep-kit
.\claude-keep-kit\setup.cmd
```

### 방법 B: 압축 파일로 받기

1. GitHub에서 `purmhyun/K.koreana` 저장소 → 브랜치 `claude/claude-work-setup-maintain-73kxlb` → **Code → Download ZIP**
2. `C:\utility\claude-keep-kit` 같은 곳에 압축을 풉니다.
3. `setup.cmd`를 더블클릭합니다. "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누릅니다.

### 방법 C: 내 PC의 Claude에게 맡기기

Claude 데스크톱 앱(Cowork 또는 Code 탭)에서 `C:\utility` 폴더를 열고 이렇게 요청합니다.

> github.com/purmhyun/K.koreana 저장소의 claude/claude-work-setup-maintain-73kxlb 브랜치를 C:\utility\claude-keep-kit 에 받아서 setup.cmd 를 실행하고 결과를 알려줘

### 실행하면

화면에 `[1/6]` ~ `[6/6]` 단계가 표시되고, 각 줄 앞의 표시로 결과를 알 수 있습니다.

- `[OK]` 완료
- `[--]` 이미 되어 있거나 건너뜀
- `[!!]` 확인이 필요함 (메시지에 해야 할 일이 적혀 있음)

여러 번 실행해도 안전합니다. 이미 있는 `CLAUDE.md`, `작업일지.md`는 덮어쓰지 않고, 처음 저장한 원래 전원 설정도 그대로 보존합니다.

### 설정 바꾸기 (선택)

```powershell
# 백업을 OneDrive 폴더에 (PC 고장에도 안전), 매일 21시에
.\claude-keep-kit\setup.cmd -BackupDir "$env:USERPROFILE\OneDrive\Claude-backup" -BackupTime 21:00

# 전원 설정은 건드리지 않기 (노트북을 들고 다닐 때) → 긴 작업 때만 keep-awake.cmd 사용
.\claude-keep-kit\setup.cmd -SkipPower
```

그 밖의 옵션: `-WorkDir`(다른 작업 폴더), `-SkipStartup`(앱 자동 실행 안 함), `-SkipBackup`(백업 예약 안 함).

## 3. 설치 후 폴더 모습

```
C:\utility\Cowork task Claude setup 2026-10-05\
├─ CLAUDE.md                   Claude가 매번 먼저 읽는 작업 규칙 (자유롭게 고쳐 쓰세요)
├─ 작업일지.md                  한 일 / 다음 할 일 기록
├─ 결과물\                      Claude가 만든 파일 저장 위치
├─ Claude-remote-control.cmd   밖에서 휴대폰/웹으로 이어가기
└─ _maintain\
   ├─ check.cmd                상태 점검 (아무것도 바꾸지 않음)
   ├─ backup-now.cmd           지금 바로 백업
   ├─ keep-awake.cmd           이 창이 열려 있는 동안만 절전 방지
   └─ uninstall.cmd            설정 되돌리기

C:\utility\Claude-backup\
├─ claude-work-20261005-230000.zip   매일 백업 (최근 14개)
└─ backup.log                        백업 기록
```

키트를 받은 폴더(`claude-keep-kit`)는 설치가 끝나면 지워도 됩니다. 필요한 스크립트는 모두 `_maintain`에 복사됩니다.

## 4. 매일 쓰는 법

1. **시작할 때**: Cowork 또는 Claude Code에서 작업 폴더를 열고 첫 메시지로
   > CLAUDE.md 와 작업일지.md 를 먼저 읽고 이어서 진행해줘

   (Claude Code는 `CLAUDE.md`를 자동으로 읽습니다. Cowork에서는 이 한 줄을 붙여 주세요.)
2. **끝낼 때**:
   > 작업일지.md 에 오늘 한 일과 다음 할 일을 적어줘
3. **긴 작업을 맡기고 자리를 비울 때**: PC 전원을 연결해 두고 Claude 앱을 켜 둡니다. setup에서 `-SkipPower`를 썼다면 `_maintain\keep-awake.cmd`도 켜 둡니다.
4. **밖에서 이어갈 때**: 나가기 전에 `Claude-remote-control.cmd`를 실행해 두면, 휴대폰이나 웹의 Claude 앱에서 이 PC의 세션이 보이고 이어서 지시할 수 있습니다. (Claude Code CLI 필요: PowerShell에서 `irm https://claude.ai/install.ps1 | iex`)
5. **가끔**: `_maintain\check.cmd`로 절전·자동 실행·백업이 살아 있는지 확인합니다.

## 5. 백업에서 되살리기

`C:\utility\Claude-backup`에서 원하는 날짜의 zip을 열고 필요한 파일만 꺼내면 됩니다. 폴더 전체를 되돌리려면:

```powershell
Expand-Archive "C:\utility\Claude-backup\claude-work-20261005-230000.zip" "C:\utility\복원_20261005"
```

현재 폴더를 덮어쓰지 않도록 새 폴더에 푼 뒤 비교해서 옮기세요.

## 6. 되돌리기

`_maintain\uninstall.cmd`를 실행하면 전원 설정을 원래 값으로 되돌리고, 자동 실행 바로가기와 백업 예약을 지웁니다. 작업 파일과 백업 zip은 지우지 않습니다.

## 7. 알아둘 점

- **노트북 덮개**: 덮개를 닫으면 절전 설정과 별개로 잠들 수 있습니다. 덮개를 닫고 쓰려면 *제어판 → 전원 옵션 → 덮개를 닫으면 수행되는 작업*에서 "전원 사용"을 "아무 것도 안 함"으로 바꾸세요. 이 키트는 이 설정을 바꾸지 않습니다.
- **화면 꺼짐·잠금은 괜찮습니다**: 화면이 꺼지거나 잠겨도 PC가 깨어 있으면 작업은 계속됩니다.
- **Windows 업데이트 재시작**: 재시작 후 로그인하면 Claude 앱은 자동으로 켜지지만, 진행 중이던 대화는 다시 지시해야 합니다. 이때 `작업일지.md`가 있으면 바로 이어갈 수 있습니다.
- **백업 위치**: 기본 백업은 같은 디스크에 있어 디스크 고장에는 대비하지 못합니다. 중요한 작업이면 `-BackupDir`로 OneDrive 같은 클라우드 동기화 폴더를 지정하세요.
- **민감한 파일**: 백업 zip에는 작업 폴더의 모든 파일이 들어갑니다. 백업 폴더를 다른 사람과 공유하지 마세요.

## 키트 구성

| 파일 | 역할 |
|---|---|
| `setup.cmd` | 더블클릭용 실행 파일 (`scripts\setup.ps1` 실행) |
| `scripts\setup.ps1` | 6단계 설정 |
| `scripts\backup.ps1` | zip 백업 + 오래된 백업 정리 |
| `scripts\keep-awake.ps1` | 실행 중에만 절전 방지 |
| `scripts\check.ps1` | 상태 점검 |
| `scripts\uninstall.ps1` | 설정 되돌리기 |
| `scripts\common.ps1` | 공통 함수 |
| `templates\CLAUDE.md`, `templates\worklog.md` | 작업 규칙·작업일지 서식 |

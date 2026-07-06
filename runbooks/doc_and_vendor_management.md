# 문서체계 및 벤더 커뮤니케이션 관리 규약

| 항목 | 내용 |
|---|---|
| 문서명 | 작성체계·업무관리·벤더 커뮤니케이션 관리 규약 |
| 버전 | v1.2 |
| 작성일 | 2026-07-04 |
| 위치 | `~/avstack-control/runbooks/doc_and_vendor_management.md` |
| 성격 | **내구성 규칙** — 상태가 아니라 체계를 정의 (상태는 PROJECT_STATUS.md) |

**Change Log**
- C1 (2026-07-04): §4.2 에 두 규약 추가 — (1) OUTBOX 초안의 내부 전용 내용은 `<!-- INTERNAL -->` 주석 표기, SENT 동결 시 제거한 발송본 저장. (2) 문의 인용 증거는 발송 전 `vendor/<사>/evidence/` 에 사본 동결.
- C2 (2026-07-06): §4.1 에 **2층 키 규칙** 추가 — 내부 키 `comm_id`(불변) + 외부 참조 키 `external_ref`(대외 노출용). vendor_comms.tsv 에 `external_ref` 컬럼 신설(schema-migration).

---

## 1. 설계 원칙

1. **원장과 뷰의 분리**: 사실의 원장은 `records/*.tsv`(append-only + AMEND). 문서는 원장의 해석·요약 뷰이며, 충돌 시 원장이 이긴다.
2. **살아있는 문서는 딱 하나**: PROJECT_STATUS.md만 매 세션 덮어쓴다. 나머지는 버전·erratum으로만 변경한다.
3. **한 문서 한 역할**: 상태(STATUS) / 규칙(runbook) / 설계(design note) / 기록(records·reports) / 대외(vendor)를 섞지 않는다.
4. **추적 가능한 대외 커뮤니케이션**: 벤더에 나간 모든 문장은 발송본 사본과 근거(evidence 경로)가 저장소에 남는다.

## 2. 디렉터리 체계 (목표 상태)

```text
avstack-control/
  PROJECT_STATUS.md            # ① 마스터 인덱스 (유일한 살아있는 문서)
  CLAUDE.md                    # Claude Code 세션 규칙 (기존)
  records/                     # ② 불변 원장
    stages.tsv  issues.tsv  decisions.tsv  commands.tsv
    vendor_comms.tsv           #    [신설] 벤더 커뮤니케이션 대장
  runbooks/                    # ③ 규칙·절차·설계 (버전 관리 대상)
    integrated_roadmap.md
    framework_design_note_v1.1.md
    avs-007_layer_diagnosis.md
    full_autonomy_analysis.md
    doc_and_vendor_management.md   # 본 문서
    avs-001_scenario_runner_window.md 등 재발방지 runbook
  reports/                     # ④ [신설] 세션 리포트·회고 (날짜 불변 기록)
    2026-07-03_session.md
    templates/session_report_template.md
  vendor/                      # ⑤ [신설] 대외 커뮤니케이션 패키지
    morai/
      OUTBOX/                  #    발송 대기 초안 (검토 완료본만)
      SENT/                    #    발송본 사본 (발송일 접두어, 이후 불변)
      INBOX/                   #    회신 원문 (수신일 접두어, 불변)
      templates/inquiry_template.md
  scripts/  env/  ...          # 기존 유지
```

**문서 유형 판별 규칙** (새 문서를 어디에 둘지 5초 판정):

| 질문 | 예 | 위치 |
|---|---|---|
| 다음 세션이 갱신하는가? | 상태 요약 | PROJECT_STATUS.md에 병합 (새 파일 금지) |
| 절차·설계·분석인가? | 진단 계획, 설계노트 | runbooks/ (버전 명기) |
| 특정 날짜의 사실 기록인가? | 세션 회고 | reports/ (날짜 접두어, 이후 불변) |
| 외부로 나가는가? | 벤더 문의 | vendor/<사>/OUTBOX → SENT |
| 한 줄 사실인가? | 명령, 판정, 결정 | records/*.tsv |

## 3. 버전·정정 규약 (기존 규약의 명문화)

- **버전**: 설계 문서는 `vN.N` + 문두 Change Log(Cn). 소수점 증가 = 내용 변경, 정수 증가 = 구조 변경.
- **Erratum**: 정본 문서의 사실 오류는 해당 절에 `> [ERRATUM YYYY-MM-DD] 정정 내용 + 근거(이슈/실측)` 블록 추가. 삭제 대신 취소선. 커밋 메시지에 `erratum:` 접두어.
- **AMEND**: TSV 과거 행 정정은 `AMEND:` 접두어 새 행 append. 동일 키 다중 행은 최신이 유효.
- **인용 규칙**: 문서 간 참조는 "문서명 + 절 번호"로. 행 번호·페이지 인용 금지(변동성).

## 4. 벤더 커뮤니케이션 관리 체계

### 4.1 vendor_comms.tsv 스키마 (원장)

```text
comm_id	external_ref	date	direction	channel	counterpart	subject	related_issues	status	evidence_path	next_action	due
MORAI-001	KATECH-SIM-ROS2	2026-07-04	OUT	email	MORAI support	ROS2 Native ros2cs 예외 및 rosbridge header.seq 질의	AVS-007	DRAFT	vendor/morai/OUTBOX/MORAI-001_avs007_inquiry.md	사용자 발송	2026-07-06
```

- **2층 키 규칙 (C2)**: `comm_id`(예: MORAI-001)는 **내부 키**로 불변·추적 전용. `external_ref`(예: KATECH-SIM-ROS2)는
  **외부 참조 키**로 대외 문서·파일명·발송본에 노출한다. 발송용 산출물(PDF/zip)은 external_ref 기반으로 명명하고,
  내부 comm_id 는 발송본에 노출하지 않는다(제목의 "(내부 ID...)" 제거 규약과 일관).
- **status 수명주기**: `DRAFT → SENT → WAITING → ANSWERED → CLOSED` (+ `STALE`: due 초과 무응답 → 리마인드 발송 후 due 갱신)
- **direction**: OUT(발송) / IN(수신). 회신 수신 시 동일 comm_id로 IN 행 추가 (스레드 유지).
- **규칙**: SENT 전환은 실제 발송과 동시에만. 발송본은 그 시점 사본을 `SENT/YYYYMMDD_<comm_id>_<제목>.md`로 동결.

### 4.2 문의 패키지 표준 (templates/inquiry_template.md)

벤더 문의 1건 = 아래 6절 구조. **핵심 원칙: 증상이 아니라 실측을 보낸다** — "안 됩니다"가 아니라 "여기까지 확인했고 이 계층에서 막힙니다".

```markdown
# [문의 제목] (내부 ID: MORAI-00X / 관련: AVS-00X)

## 1. 요약 (3줄 이내)
무엇이, 어느 계층에서, 어떤 실측 근거로 막히는지.

## 2. 환경
SIM/Runner 버전, OS, GPU/드라이버, ROS2 배포판·RMW, Python — VERSIONS.lock 발췌.

## 3. 재현 절차
번호 매긴 단계. 우리가 3회 재현했음을 명시.

## 4. 실측 증거
로그 발췌(원문 첨부 목록), 스크린샷, 계층 진단 결과(예: D1 tcpdump 요약).
각 증거의 저장소 내 경로를 병기 (내부 추적용 — 발송본에서는 경로 제거 가능).

## 5. 질문 (번호, 예/아니오로 답할 수 있게)
Q1. ... Q2. ...

## 6. 요청 사항 / 기능 제안 (선택)
예: CLI/설정파일 기반 ROS 연결 옵션 제공 여부·로드맵.
```

- **내부 전용 표기 (C1)**: OUTBOX 초안의 내부 전용 내용(제목 아래 안내문, "내부 추적용" 경로, 스레드 분리 주석 등)은 `<!-- INTERNAL: ... -->` 주석으로 표기하며, SENT 동결 시 이 주석 블록을 제거한 발송본을 저장한다.
- **증거 동결 (C1)**: 문의에 인용된 증거는 발송 전 `vendor/<사>/evidence/` 에 사본을 동결한다(대외 주장의 근거는 git 관리 영역에 있어야 한다).

### 4.3 현재 관리 대상 3건 (초기 등록분)

| comm_id | 관련 | 내용 | 상태 |
|---|---|---|---|
| MORAI-001 | AVS-007 | ROS2 Native(ros2cs 예외) + rosbridge(header.seq) 실측 질의. **D1~D4 진단 완료 시 4절에 증거 보강 후 발송이 이상적이나, 진단이 지연되면 현 증거로 선발송** | DRAFT |
| MORAI-002 | AVS-006 | sourcedefender 보호 Python API: 지원 Python 버전, 공식 설치 절차, 라이선스/만료 조건, conda 권장 환경 | 초안 필요 |
| MORAI-003 | R18/자율화 | 기능 요청: ① ROS 연결의 CLI/설정파일화 ② 시나리오 시작 시 자동 Connect ③ 런처 자동기동 인자 ④ Headless 지원 로드맵 | 초안 필요 |

**발송 전략**: MORAI-001·002는 즉시성(블로커 해제), MORAI-003은 관계성(기능 요청) — 001/002 스레드가 살아있을 때 병행 제기하면 응답률이 높다. 세 건을 한 메일에 합치지 않는다 (스레드별 추적 불가능해짐).

### 4.4 회신 처리 절차

1. 회신 원문을 `INBOX/YYYYMMDD_<comm_id>_reply.md`로 저장 (불변)
2. vendor_comms.tsv에 IN 행 추가, status=ANSWERED
3. 회신 내용의 사실을 분류: 설계노트 erratum 대상 / 이슈 해제 조건 / 새 제약(Risk 등재)
4. 조치 완료 시 CLOSED + 관련 AVS 이슈 갱신

## 5. 세션 리포트 규약 (reports/)

템플릿 `reports/templates/session_report_template.md`:

```markdown
# 세션 리포트 YYYY-MM-DD

## 목표 (세션 시작 시 선언한 것)
## 완료
## 미완 + 이유
## 신규: 이슈 / 결정 / 벤더 커뮤니케이션 (TSV 반영 여부 체크)
## 교훈 (CLAUDE.md 규칙 승격 후보 표시)
## 다음 세션 필수 작업 (PROJECT_STATUS 7장에 반영했는지 체크)
```

- 파일명 `YYYY-MM-DD_session.md`, 하루 2세션이면 `_2` 접미어. 작성 후 불변.
- 지난 세션들의 회고 문서·분석 리포트도 이 폴더로 소급 이관한다.

## 6. Claude Code 적용 프롬프트

```text
runbooks/doc_and_vendor_management.md 를 읽고 문서·벤더 관리 체계를 저장소에 적용한다.

작업:
1. 디렉터리 신설: reports/, reports/templates/, vendor/morai/{OUTBOX,SENT,INBOX,templates}
   (git이 빈 폴더를 추적하지 않으므로 각각 .gitkeep 또는 첫 파일과 함께 커밋)
2. records/vendor_comms.tsv 를 문서 4.1 스키마의 헤더로 생성하고,
   4.3의 3건(MORAI-001/002/003)을 등록해라. 001은 DRAFT + 기존 문의 초안 경로,
   002/003은 status=TODO_DRAFT로.
3. 기존 파일 이관 (git mv 사용, 경로 참조하는 문서·스크립트가 있으면 함께 수정):
   - avs-007 MORAI 문의 초안 → vendor/morai/OUTBOX/MORAI-001_avs007_inquiry.md
   - 지난 세션 분석 리포트·회고 문서 → reports/2026-07-03_session.md (내용 병합·요약 금지, 이동만)
4. vendor/morai/templates/inquiry_template.md 를 문서 4.2 그대로 생성.
   reports/templates/session_report_template.md 를 문서 5장 그대로 생성.
5. MORAI-001 초안을 4.2 템플릿 구조로 재정렬해라 (내용 추가·삭제 금지, 절 재배치만).
   재배치 결과 diff를 보여주고 내 승인 후 확정.
6. MORAI-002 초안을 새로 작성해라. 근거는 issues.tsv의 AVS-006 기록과
   실측 사실만 사용하고, 추정이 필요한 부분은 [확인 필요] 표시 후 나에게 질문해라.
7. PROJECT_STATUS.md 를 저장소 루트에 배치하고 (내가 제공한 파일),
   CLAUDE.md 상단에 다음 1줄을 추가해라:
   "세션 시작 시 PROJECT_STATUS.md 를 먼저 읽고, 종료 시 갱신한다 (8장 인수인계 규약)."
8. 커밋 분리: (a) 체계 신설(디렉터리+TSV+템플릿) (b) 파일 이관 (c) MORAI-001 재정렬
   (d) MORAI-002 초안. 각각 별도 커밋, 메시지 접두어 "docs:" 또는 "vendor:".

제약:
- 기존 TSV 스키마 변경 금지. vendor_comms.tsv는 신규 파일이므로 자유.
- SENT/INBOX 에는 아무것도 만들지 마라 (실제 발송·수신 시에만 기록).
- MORAI-001의 기술적 내용을 임의로 보강하지 마라 — 증거 추가는 D1~D4 실측 후 별도 작업.
```

## 7. 운영 체크리스트 (사람용, 주 1회)

- [ ] PROJECT_STATUS 스냅샷 날짜가 7일 이내인가
- [ ] vendor_comms.tsv에 due 초과 WAITING이 있는가 → 리마인드
- [ ] reports/에 지난 세션 리포트가 빠짐없이 있는가
- [ ] Erratum Queue(PROJECT_STATUS 5장)가 줄고 있는가
- [ ] OUTBOX에 7일 이상 머문 DRAFT가 있는가 → 발송하거나 폐기 결정

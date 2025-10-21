# Falco 데모 시나리오

이 문서는 Falco의 핵심 규칙들을 트리거하고, 그 탐지 결과를 확인하는 시연 절차를 안내합니다.

## 1. 아키텍처 다이어그램

Falco 데모 환경의 이벤트 흐름은 다음과 같습니다.

```mermaid
graph LR
    A[Client] -- kubectl exec --> B(Pod)
    B -- syscalls --> C[Falco DaemonSet (eBPF)]
    C -- Falco Events --> D[Falcosidekick]
    D -- SNS --> E(AWS SNS)
    D -- stdout --> F(Console Output)
```

## 2. 시연 절차

아래 스크립트 순서대로 실행하여 Falco 규칙 위반을 시뮬레이션하고 탐지 결과를 확인합니다.

### 2.1. 환경 설정

```bash
# kind 클러스터 생성
./scripts/kind_up.sh

# Falco 설치 (kind 환경용)
./scripts/install_falco.sh

# Falcosidekick 설치 (stdout 출력용)
./scripts/install_sidekick_stdout.sh

# 데모용 네임스페이스 및 Pod 배포
kubectl apply -f manifests/demo/ns.yaml
kubectl apply -f manifests/demo/pod-alpine.yaml

# Pod가 준비될 때까지 대기
kubectl wait --for=condition=ready pod/alpine-demo -n falco-demo --timeout=120s
```

### 2.2. 규칙 트리거 및 로그 확인

`./scripts/demo_triggers.sh` 스크립트를 실행하여 모든 핵심 Falco 규칙을 순차적으로 트리거합니다. 스크립트 실행 후 Falco 로그를 확인하여 각 규칙에 대한 알림이 올바르게 생성되었는지 검증합니다.

```bash
./scripts/demo_triggers.sh
```

**예상 로그 스니펫 (Falcosidekick stdout)**:

`kubectl -n falco logs -l app.kubernetes.io/name=falcosidekick` 명령어를 통해 다음과 유사한 로그를 확인할 수 있습니다.

```json
# SHELL in container
{"output":"SHELL in container (user=root ns=falco-demo pod=alpine-demo proc=sh cmd=sh -lc echo \"[demo] shell spawned\"; apk update || true)","priority":"Warning", ...}

# PKG MANAGER
{"output":"PKG MANAGER in container (proc=apk ns=falco-demo pod=alpine-demo cmd=apk update)","priority":"Notice", ...}

# WRITE sensitive file under /etc
{"output":"WRITE sensitive file under /etc (file=/etc/passwd ns=falco-demo pod=alpine-demo user=root cmd=sh -lc echo \"* * * * * echo hi\" >> /etc/cron.d/demo || true)","priority":"Critical", ...}

# IMDS access from container
{"output":"IMDS access from container (ns=falco-demo pod=alpine-demo proc=wget -> 169.254.169.254:80 cmd=wget -qO- http://169.254.169.254/latest/meta-data/ || true)","priority":"High", ...}

# SUSPICIOUS outbound
{"output":"SUSPICIOUS outbound (ns=falco-demo pod=alpine-demo dst=127.0.0.1:4444 proc=nc cmd=nc -zv 127.0.0.1 4444 || true)","priority":"Medium", ...}

# PERM change on system path
{"output":"PERM change on system path (op=chmod file=/etc/demo ns=falco-demo pod=alpine-demo user=root cmd=touch /etc/demo && chmod 777 /etc/demo || true)","priority":"Medium", ...}

# ... (다른 규칙에 대한 로그 스니펫)
```

### 2.3. 환경 정리

데모가 완료되면 다음 명령어를 사용하여 모든 리소스를 정리합니다.

```bash
./scripts/cleanup.sh
```

## 3. 트러블슈팅

Falco 데모 환경 설정 및 실행 중 발생할 수 있는 일반적인 문제와 해결 방법입니다.

### 3.1. eBPF 드라이버 미로드 또는 오류

*   **증상**: Falco Pod가 `CrashLoopBackOff` 상태이거나, Falco 로그에 드라이버 로드 실패 메시지가 표시됩니다.
*   **원인**: Kubernetes 노드의 커널 헤더가 Falco 드라이버와 호환되지 않거나, eBPF 관련 커널 모듈이 로드되지 않았을 수 있습니다.
*   **해결**: 
    *   `kind` 클러스터의 경우, `kind` 버전을 업데이트하거나 다른 `kind` 이미지 버전을 시도해 보세요.
    *   `kubectl -n falco logs falco-xxxx` 명령어로 Falco Pod의 상세 로그를 확인하여 정확한 오류 메시지를 파악합니다.
    *   Falco 공식 문서에서 사용 중인 커널 버전과 Falco 버전의 호환성 매트릭스를 확인합니다.

### 3.2. 권한 문제

*   **증상**: Falco 또는 Falcosidekick Pod가 특정 리소스에 접근하지 못하거나, 알림을 전송하지 못합니다.
*   **원인**: Kubernetes RBAC 설정이 잘못되었거나, EKS 환경에서 IRSA 역할에 필요한 권한이 부여되지 않았을 수 있습니다.
*   **해결**: 
    *   `kubectl auth can-i ...` 명령어를 사용하여 Falco 및 Falcosidekick 서비스 어카운트의 권한을 확인합니다.
    *   EKS+SNS 구성의 경우, `infra/aws/irsa.tf`에 정의된 IAM 역할에 SNS Publish 권한이 올바르게 부여되었는지, 그리고 `falcosidekick-values.sns.yaml`의 `eks.amazonaws.com/role-arn` 어노테이션이 올바른지 확인합니다.

### 3.3. 커널 버전 호환성

*   **증상**: Falco가 시작되지 않거나, 예상치 못한 동작을 보입니다.
*   **원인**: Falco는 커널의 특정 기능에 의존하므로, 오래되거나 지원되지 않는 커널 버전에서는 문제가 발생할 수 있습니다.
*   **해결**: 
    *   `uname -r` 명령어로 노드의 커널 버전을 확인합니다.
    *   Falco 공식 문서에서 지원되는 커널 버전 목록을 참조하고, 필요한 경우 커널을 업데이트합니다.
    *   `kind` 클러스터의 경우, `kind` 이미지 버전을 변경하여 다른 커널 버전을 가진 노드를 사용해 볼 수 있습니다.

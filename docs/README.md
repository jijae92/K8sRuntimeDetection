# K8s Runtime Detection (Falco mini) - Immediate Notification of Behavior

## 1. 목적 및 구성

이 프로젝트는 Kubernetes 런타임 환경에서 Falco를 활용하여 위협을 탐지하고, 탐지된 행위에 대해 즉각적으로 알림을 제공하는 것을 목표로 합니다. 주요 구성 요소는 다음과 같습니다:

*   **Falco DaemonSet (eBPF)**: 커널 시스템 호출을 모니터링하여 의심스러운 행위를 탐지합니다. eBPF 드라이버를 사용하여 고성능 및 안정성을 제공합니다.
*   **Falcosidekick**: Falco에서 생성된 이벤트를 다양한 외부 시스템으로 전송하는 유연한 아웃풋 컨버터입니다. 여기서는 AWS SNS 또는 표준 출력(stdout)으로 알림을 보냅니다.
*   **AWS SNS (Simple Notification Service)**: 클라우드 환경(EKS)에서 Falco 알림을 수신하고, 이를 구독자에게 푸시하는 데 사용됩니다.
*   **stdout**: 로컬 개발 환경(kind)에서 Falco 알림을 콘솔에 직접 출력하여 즉각적인 피드백을 제공합니다.



## 3. EKS + SNS 구성

AWS EKS 환경에서 Falco 알림을 SNS로 전송하도록 구성하는 방법입니다.

1.  **AWS 인프라 배포 (SNS, IRSA)**:
    `infra/aws` 디렉토리의 Terraform 스크립트를 사용하여 SNS 토픽과 Falcosidekick을 위한 IRSA(IAM Role for Service Accounts)를 생성합니다.
    ```bash
    cd infra/aws
    terraform init
    terraform apply
    ```

2.  **환경 변수 설정**: Terraform 출력에서 얻은 `SNS_TOPIC_ARN`, `FALCOSIDEKICK_ROLE_ARN` 및 `AWS_REGION`을 환경 변수로 설정합니다.
    ```bash
    export AWS_REGION="your-aws-region"
    export SNS_TOPIC_ARN="arn:aws:sns:your-aws-region:account-id:falco-alerts"
    export FALCOSIDEKICK_ROLE_ARN="arn:aws:iam::account-id:role/falcosidekick-irsa"
    ```

3.  **Falco 설치**: `falco-values.eks.yaml` 설정을 사용하여 EKS에 Falco를 설치합니다.
    ```bash
    make falco-install-eks
    ```

4.  **Falcosidekick (SNS) 설치**: `falcosidekick-values.sns.yaml` 설정을 사용하여 Falco 이벤트를 SNS로 보내는 Falcosidekick을 설치합니다.
    ```bash
    make sidekick-install-sns
    ```
    이제 Falco 알림이 설정된 SNS 토픽으로 전송됩니다.

## 4. 핵심 Falco 규칙 및 트리거 예시

다음 표는 이 프로젝트에 포함된 10가지 핵심 Falco 규칙과 각 규칙을 트리거하는 간략한 예시를 보여줍니다.

| 번호 | 규칙 이름                 | 설명                                     | 트리거 예시                                                              | 우선순위 |
|----|-----------------------|------------------------------------------|--------------------------------------------------------------------------|----------|
| 1  | Container Spawned Shell | 컨테이너 내에서 쉘이 실행될 때 탐지       | `kubectl exec ... sh`                                                    | WARNING  |
| 2  | Write Below Etc Sensitive | 컨테이너 내에서 `/etc/passwd`, `/etc/shadow`, `/etc/group` 파일 수정 시 탐지 | `kubectl exec ... echo >> /etc/passwd`                                   | CRITICAL |
| 3  | Modify System Binaries    | 컨테이너 내에서 `/bin` 또는 `/usr/bin` 디렉토리의 파일 수정 시 탐지 | `kubectl exec ... echo >> /bin/ls`                                       | HIGH     |
| 4  | Package Manager Launched  | 컨테이너 내에서 패키지 관리자 실행 시 탐지 | `kubectl exec ... apk update`                                            | NOTICE   |
| 5  | Contact Cloud Metadata    | 컨테이너가 클라우드 메타데이터 서비스에 접근 시 탐지 | `kubectl exec ... curl 169.254.169.254`                                  | HIGH     |
| 6  | Mount Execution In Container | 컨테이너 내에서 `mount` 시스템 호출 실행 시 탐지 | `kubectl exec ... mount ...` (데모 스크립트에서는 직접 트리거하지 않음) | HIGH     |
| 7  | Privileged Container      | `privileged=true`로 시작된 컨테이너 탐지 | `kubectl run --privileged ...` (배포 시점 탐지)                         | CRITICAL |
| 8  | Write Cron Files          | 컨테이너 내에서 cron 파일 수정 시 탐지   | `kubectl exec ... echo >> /etc/cron.d/demo`                              | MEDIUM   |
| 9  | Outbound Suspicious Ports | 컨테이너에서 의심스러운 C2 포트로 아웃바운드 연결 시 탐지 | `kubectl exec ... nc -zv 1.2.3.4 4444`                                   | MEDIUM   |
| 10 | Permission Change System Paths | 컨테이너 내에서 `/etc` 또는 시스템 바이너리 경로의 파일 권한 변경 시 탐지 | `kubectl exec ... chmod 777 /etc/demo`                                   | MEDIUM   |

## 5. 노이즈 제어 가이드

Falco 규칙에서 발생하는 노이즈를 줄이고 오탐을 제어하기 위해 `rules/custom_rules.yaml` 파일의 `allowed_images` 및 `allowed_namespaces` 리스트를 튜닝할 수 있습니다.

*   **`allowed_images`**: Falco 이벤트를 생성하지 않아야 하는 신뢰할 수 있는 컨테이너 이미지 목록을 추가합니다. 예를 들어, `pause` 컨테이너와 같이 정상적인 시스템 동작에 필요한 이미지들을 여기에 포함할 수 있습니다.
*   **`allowed_namespaces`**: Falco 규칙이 적용되지 않아야 하는 Kubernetes 네임스페이스 목록을 추가합니다. `kube-system` 또는 `gatekeeper-system`과 같이 관리형 서비스가 실행되는 네임스페이스는 종종 예외 처리될 수 있습니다.

이러한 리스트를 신중하게 관리하여 보안 가시성을 유지하면서도 불필요한 알림을 줄일 수 있습니다.

## 6. 보안 및 컴플라이언스 주석

*   **최소 권한 원칙**: Falcosidekick의 AWS IAM Role (IRSA) 설정 시, SNS Publish 권한은 특정 SNS 토픽 ARN으로 제한하는 것이 좋습니다. 현재 `Resource = ["*"]`로 설정되어 있으나, 프로덕션 환경에서는 반드시 최소 권한으로 변경해야 합니다.
*   **규칙 지속적인 검토**: 제공된 Falco 규칙은 일반적인 위협을 탐지하지만, 환경에 특화된 위협을 탐지하기 위해 규칙을 지속적으로 검토하고 업데이트해야 합니다.
*   **커널 버전 호환성**: Falco는 커널 모듈 또는 eBPF 드라이버를 사용하므로, Kubernetes 노드의 커널 버전과 Falco 버전 간의 호환성을 항상 확인해야 합니다.
*   **로그 및 모니터링**: Falco 알림은 보안 운영 센터(SOC) 또는 SIEM 시스템으로 통합되어야 하며, 지속적인 모니터링 및 분석이 이루어져야 합니다.

## 빠른 시작
1) make up
2) make falco && make sidekick
3) make demo
4) make logs  # "SHELL in container", "PKG MANAGER", "IMDS access" 등 룰명 확인
5) make down

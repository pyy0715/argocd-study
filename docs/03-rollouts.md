# 03 — Argo Rollouts로 점진 배포

**목표**: Stage 2의 Deployment를 Rollout으로 교체해 canary 단계적 확대와 수동 promote/abort를 경험합니다.

## Flow

```
이미지가 ghcr.io에 push
  └─ Image Updater가 태그 반영 (Stage 2와 동일)
      └─ Rollout CR이 새 ReplicaSet 생성
          └─ canary steps에 따라 20% → 40% → 60% → 80% → 100% 확대
              └─ 각 step 사이 pause. 수동 promote 또는 abort 가능
```

## Install Argo Rollouts

```bash
./bootstrap/install-rollouts.sh
```

선택: kubectl 플러그인.

```bash
brew install argoproj/tap/kubectl-argo-rollouts
# 또는
mise use -g argo-rollouts
```

## Replace Deployment with Rollout

`app/deployment.yaml`에서 Deployment 리소스를 `app/rollout.yaml.example`의 Rollout으로 교체합니다. Service 정의는 그대로 둡니다.

```bash
# 예시: deployment.yaml의 Deployment 부분만 교체
mv app/deployment.yaml app/workload.yaml
# app/workload.yaml 안의 Deployment를 Rollout으로 수동 교체하거나,
# 아래처럼 새 파일 구조로 분리하는 편이 깔끔
```

깔끔한 분리 방식:

```bash
cat app/rollout.yaml.example | sed '/^#/d' > app/rollout.yaml
# 그리고 app/deployment.yaml에서 Deployment 블록을 삭제, Service만 남김
```

최종 `app/` 구조 예시:

```
app/
├── rollout.yaml      # Rollout (Deployment 대체)
└── service.yaml      # Service만 분리
```

그리고 Git에 commit, push. ArgoCD가 Rollout CR을 생성합니다.

## Observe

```bash
kubectl argo rollouts get rollout hello -n hello --watch
```

각 step 사이 30초 pause가 있습니다. 새 이미지를 push하면 canary ReplicaSet이 20%부터 시작합니다.

### Manual Control

```bash
# 현재 paused 상태인 step을 바로 promote
kubectl argo rollouts promote hello -n hello

# 전체 abort (stable로 롤백)
kubectl argo rollouts abort hello -n hello

# abort 후 다시 진행
kubectl argo rollouts retry rollout hello -n hello
```

## Notes

- **점진 확대**: replica 비율로 근사 canary weight를 구현합니다. k3s에는 traffic manager가 없으므로 정교한 weight(1%, 5%)는 불가능합니다.
- **실패 격리**: 새 버전이 문제를 일으키면 abort로 stable로 즉시 되돌릴 수 있습니다. blast radius가 단계당 20%로 제한됩니다.
- **CRD 차이**: Rollout은 Deployment와 거의 동일한 spec을 쓰지만, `strategy.canary`나 `strategy.blueGreen`을 추가로 선언합니다.

## Advanced Traffic Splitting (Optional)

프로덕션에서 의미 있는 canary를 구현하려면 traffic manager와 연결합니다.

- **AWS ALB**: AWS Load Balancer Controller의 weighted target group 결합
- **Istio**: VirtualService의 weight 필드 조정
- **Gateway API**: HTTPRoute backendRef weight (Argo Rollouts 1.8+ GA)

또한 **AnalysisTemplate**을 연결하면 Prometheus 쿼리 기반 자동 promote/abort가 가능합니다. 이 repo는 로컬 실습 범위라 AnalysisTemplate은 생략합니다.

## Stage Comparison

| | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| 이미지 태그 반영 | Actions bump PR | Image Updater 자동 | Image Updater 자동 |
| 승인 gate | PR 리뷰 | 없음(registry 보호 의존) | 없음 + canary pause로 완화 |
| 실패 시 복구 | git revert + 재배포 | git revert + 재배포 | abort로 즉시 stable 복귀 |
| 복잡도 | 낮음 | 중간 | 높음 |
| 추가 의존 | GitHub Actions | Image Updater Pod | Image Updater + Rollouts + (선택) traffic manager, 메트릭 |

실무에서는 **Stage 1 + Stage 3** 조합이 흔합니다. CI의 승인 gate는 유지하면서 배포 자체는 점진 확대와 자동 롤백으로 보호합니다.

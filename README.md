# ArgoCD Study

로컬 docker-compose로 k3s를 띄우고 그 위에 ArgoCD를 설치한 뒤, 같은 애플리케이션을 가지고
이미지 배포 자동화 방식을 세 단계로 발전시키며 각 조합의 장단점을 체감하는 학습용 저장소입니다.

각 단계는 **이전 단계의 구성에서 다음 단계로 전환**하는 방식이라, 세 방식을 동시에 병렬 배포
하지 않고 같은 `hello` Application을 파이프라인만 바꿔가며 관찰합니다.

## Requirements

- Docker Desktop
- `kubectl`
- `make`

## Stages

| Stage | 조합 | 문서 |
|---|---|---|
| 1 | ArgoCD + GitHub Actions | [docs/01-actions-bump.md](docs/01-actions-bump.md) |
| 2 | ArgoCD + Image Updater (1의 Actions bump 대체) | [docs/02-image-updater.md](docs/02-image-updater.md) |
| 3 | ArgoCD + Image Updater + Rollouts (2의 Deployment를 Rollout으로 교체) | [docs/03-rollouts.md](docs/03-rollouts.md) |

## Concepts

Stage 문서가 "어떻게 하는지"라면, concepts 문서는 "왜 그렇게 되는지".

- [ArgoCD Internals](docs/concepts/argocd-internals.md) — repo-server의 매니페스트 렌더링, sync flow, tool detection, 캐시 등
- [Image Bump Ownership](docs/concepts/image-bump-ownership.md) — 누가 이미지 태그 bump를 할 것인가. CI vs 컨트롤러 패턴 비교와 Stage 1→2 전환 근거
- [Controller Coordination via CRs](docs/concepts/controller-coordination.md) — Image Updater 와 Argo CD 가 직접 통신 없이 `Application` CR 을 공유 게시판으로 쓰는 방식

## Layout

```
.
├── docker-compose.yml            # k3s-in-docker
├── Makefile                      # up / down / password / port-forward
├── bootstrap/
│   ├── install-argocd.sh
│   ├── install-image-updater.sh     # Stage 2에서 실행 (v1.x, CRD model)
│   ├── install-rollouts.sh          # Stage 3에서 실행
│   ├── hello-app.yaml               # ArgoCD Application 정의
│   └── image-updater-hello.yaml     # Stage 2: ImageUpdater CR
├── app/
│   ├── deployment.yaml              # Deployment + Service. Stage 3에서 rollout.yaml로 교체
│   ├── kustomization.yaml           # Stage 1부터 이미지 태그는 kustomize image override 로 관리
│   └── rollout.yaml.example         # Stage 3에서 참고할 Rollout 템플릿
├── sample-app/src/
│   ├── Dockerfile
│   └── index.html
├── .github/workflows/
│   ├── image-build.yml              # 이미지 빌드 + ghcr push (bump 는 Stage 2 부터 Image Updater 가 수행)
│   └── archive/
│       └── image-build-with-bump.yml  # Stage 1 원형 (on: {} 로 비활성화)
└── docs/
    ├── 01-actions-bump.md
    ├── 02-image-updater.md
    └── 03-rollouts.md
```

## Quick start

```bash
make up              # k3s + ArgoCD 기동
make password        # 초기 admin 비밀번호
make port-forward    # https://localhost:8080
```

이후 [docs/01-actions-bump.md](docs/01-actions-bump.md)부터 순서대로 진행합니다.

## Cleanup

```bash
kubectl delete -f bootstrap/hello-app.yaml
make down            # 컨테이너 중지
make reset           # 볼륨 포함 완전 초기화 후 재기동
```

## References

- [Argo CD](https://argo-cd.readthedocs.io/)
- [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [argoproj/argocd-example-apps](https://github.com/argoproj/argocd-example-apps)

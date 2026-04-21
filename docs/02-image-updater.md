# 02 — Image Updater로 전환

**목표**: Stage 1의 Actions bump 단계를 Image Updater로 대체합니다. 이미지가 ghcr.io에 푸시되기만 하면 registry polling으로 자동 반영되는 경로를 확인합니다.

## 흐름

```
이미지가 ghcr.io에 push (CI든 수동이든)
  └─ Image Updater Pod가 registry polling (기본 2분 주기)
      └─ 새 태그 감지 → write-back-method: git → .argocd-source-hello.yaml 커밋
          └─ ArgoCD 감지 → hello 네임스페이스에 배포
```

## Install Image Updater

```bash
./bootstrap/install-image-updater.sh
```

스크립트 출력의 안내에 따라 다음 Secret과 ConfigMap을 생성합니다.

### 1. GHCR PAT

- **registry read PAT**: `read:packages` scope
- **repo write PAT**: `repo` scope

실습용이면 두 scope를 모두 가진 PAT 하나로 겸용할 수 있습니다.

### 2. Kubernetes Secrets

```bash
kubectl -n argocd create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PAT

kubectl -n argocd create secret generic git-creds \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_PAT
```

### 3. Git commit 저자

```bash
kubectl -n argocd patch configmap argocd-image-updater-config \
  --patch '{"data":{"git.user":"image-updater[bot]","git.email":"updater@example.com"}}'
```

## Application annotation 추가

`bootstrap/hello-app.yaml`의 주석 처리된 annotation 블록을 활성화합니다.

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: hello=ghcr.io/YOUR_USERNAME/argocd-study/hello
    argocd-image-updater.argoproj.io/hello.update-strategy: newest-build
    argocd-image-updater.argoproj.io/hello.pull-secret: pullsecret:argocd/ghcr-creds
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
```

annotation 의미:

- `image-list`: `alias=registry/repo` 형식. 여러 이미지는 쉼표로 구분.
- `<alias>.update-strategy`: `semver`, `newest-build`, `alphabetical`, `digest` 중 택 1.
- `<alias>.pull-secret`: private registry 자격 증명 Secret 참조.
- `write-back-method`: `argocd`(API 직접 수정) 또는 `git`(파일 커밋). git이 GitOps 원칙에 부합.
- `git-branch`: write-back 대상 브랜치.

변경 후 다시 apply:

```bash
kubectl apply -f bootstrap/hello-app.yaml
kubectl -n argocd logs deploy/argocd-image-updater -f
```

## (선택) GitHub Actions 비활성

Image Updater로 전환했으면 `.github/workflows/image-build.yml`의 `bump-manifest` job은 중복입니다. 이미지 빌드는 남기되 bump는 Updater에게 넘기려면 `bump-manifest` job을 제거하거나 workflow 전체를 `workflow_dispatch` 전용으로 돌립니다.

## 트리거

```bash
# 로컬에서 빌드 + push (Actions 없이 Stage 2 동작 확인)
TAG=test-$(date +%s)
docker build -t ghcr.io/YOUR_USERNAME/argocd-study/hello:${TAG} sample-app/src
docker push ghcr.io/YOUR_USERNAME/argocd-study/hello:${TAG}
```

Updater 로그에 감지 기록이 뜨고, Git에 `.argocd-source-hello.yaml` 커밋이 자동 생성됩니다. ArgoCD가 이어서 sync합니다.

## 관찰 포인트

- **CI 의존 제거**: 이미지가 어디서 올라오든 Updater가 감지합니다.
- **승인 단계 약화**: CI의 테스트/스캔 관문을 거치지 않으므로 registry 자체 보호(이미지 서명, 취약점 스캔)가 중요해집니다.
- **중앙 관리**: 여러 Application의 이미지 정책을 Updater 하나로 통제할 수 있습니다.
- **폴링 주기**: 기본 2분. `--interval` 플래그로 조정. registry 호출 비용과 반영 지연의 trade-off.

## 한계

- 새 이미지가 감지되면 곧바로 전체 replicas에 적용됩니다. 점진 확대, 자동 롤백이 없습니다.
- 프로덕션에서는 이 단계로만 가면 잘못된 이미지가 전체를 덮을 위험이 큽니다.

이 한계를 [03 — Rollouts](03-rollouts.md)로 해소합니다.

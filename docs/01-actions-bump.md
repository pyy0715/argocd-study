# 01 — ArgoCD + GitHub Actions

**목표**: ArgoCD가 `app/deployment.yaml`을 동기화하고, GitHub Actions가 이미지 빌드와 태그 bump PR을 담당하는 전형적인 GitOps 흐름을 경험합니다.

## 흐름

```
sample-app/src/** 수정 → push
  └─ Actions: 이미지 빌드 → ghcr.io push
      └─ Actions: app/deployment.yaml의 image 태그 bump PR 생성
          └─ PR 리뷰 & merge
              └─ ArgoCD가 hello 네임스페이스에 배포
```

## 사전 설정

1. 이 repo를 GitHub에 push합니다.
2. `YOUR_USERNAME`을 전부 실제 계정으로 교체합니다.
   ```bash
   sed -i.bak "s|YOUR_USERNAME|your-github-id|g" \
     bootstrap/hello-app.yaml \
     app/deployment.yaml \
     app/rollout.yaml.example
   ```
3. GitHub repo → Settings → Actions → General → Workflow permissions
    - **Read and write permissions** 활성화
    - **Allow GitHub Actions to create and approve pull requests** 체크

## Apply

```bash
make up                                   # k3s + ArgoCD 설치
make password                             # admin 비밀번호 확인
kubectl apply -f bootstrap/hello-app.yaml
make status
```

ArgoCD UI(`make port-forward` 후 https://localhost:8080)에서 `hello` Application이 Synced, Healthy로 올라옵니다.

## 트리거

```bash
echo "<p>$(date)</p>" >> sample-app/src/index.html
git add sample-app/src/index.html
git commit -m "test: refresh page"
git push origin main
```

Actions 탭에서 `image-build` workflow가 돌아가고, 완료되면 `bump-image-sha-XXXXXXX` 브랜치가 만들어지며 PR이 자동 열립니다. PR을 merge하면 ArgoCD가 3분 내에 새 태그로 배포합니다.

## 관찰 포인트

- **감사 추적**: 태그 bump가 Git 이력에 그대로 남습니다. 어느 커밋이 어떤 버전을 배포했는지 추적됩니다.
- **승인 지점**: PR 리뷰가 배포 직전 gate 역할을 합니다. CI 실패 시 PR이 머지되지 않아 배포도 차단됩니다.
- **app repo 분리**: 실무에서는 애플리케이션 소스 repo와 매니페스트 repo를 나누어 CI 토큰이 매니페스트 repo에만 write 권한을 갖도록 설계합니다.

## 한계

- Actions 워크플로를 직접 관리해야 합니다.
- 이미지가 외부에서 올라오는(ECR 자동 빌드, 외부 팀 전달) 경우 bump 트리거를 추가로 설계해야 합니다.
- 여러 애플리케이션 이미지를 중앙에서 관리하기 번거롭습니다.

이 한계를 [02 — Image Updater](02-image-updater.md)로 해소합니다.

# GitHub Actions Deployment

Use this workflow only after the single-host deploy scripts and server permissions are already working manually.

## Generate a Deploy Key

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_key -N ""
cat ~/.ssh/github_deploy_key
cat ~/.ssh/github_deploy_key.pub
```

Add the public key to the server:

```bash
echo "PASTE_PUBLIC_KEY" >> /home/<DEPLOY_USER>/.ssh/authorized_keys
```

## Required GitHub Secrets

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY`

## Sudoers Entry for Non-Interactive Reload

```bash
sudo tee /etc/sudoers.d/<APP_NAME>-deploy >/dev/null <<EOF
<DEPLOY_USER> ALL=(root) NOPASSWD: /usr/bin/systemctl reload php<PHP_VERSION>-fpm
EOF
sudo chmod 440 /etc/sudoers.d/<APP_NAME>-deploy
```

## Deploy Workflow

Create `.github/workflows/deploy.yml` using your preferred runner policy. The critical flow is:

1. Checkout the repository.
2. Install PHP, pnpm, Node.js, and Composer dependencies.
3. Run the test suite.
4. Build frontend assets.
5. SSH into the server and run the configured deploy script.

If you use `actions/setup-node` with `cache: pnpm`, run `pnpm/action-setup` first so the cache wiring works correctly.

Example deploy step:

```yaml
- name: Deploy via SSH
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.DEPLOY_HOST }}
    username: ${{ secrets.DEPLOY_USER }}
    key: ${{ secrets.DEPLOY_SSH_KEY }}
    timeout: 300s
    script: |
      /home/${{ secrets.DEPLOY_USER }}/scripts/deploy.sh
```

## Rollback Workflow

Expose rollback as a manual `workflow_dispatch` action that SSHes to the server and runs:

```bash
/home/<DEPLOY_USER>/scripts/rollback.sh
```

## Operational Rule

Do not make GitHub Actions the first time you test deployment. Prove the server scripts manually, then automate the known-good path.

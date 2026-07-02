# Purefox / img.purefox.org Deployment

This deployment profile runs image2api behind a host-level Nginx that already owns public `80/443` and TLS certificates.

It intentionally keeps the upstream one-command deployment separate:

- Keeps `web` in Docker, but exposes it only as HTTP on `127.0.0.1:18087`.
- Removes the `acme` sidecar and frontend container certificate scripts from this profile.
- Reuses the host wildcard certificate for `*.purefox.org`.
- Keeps PostgreSQL, Redis, RustFS, backend, and web on a private Docker network.
- Stores persistent data as bind mounts under `/srv/image2api/data/` by default for easier migration.

## Server Layout

```text
/srv/image2api/
  app/       # application source
  deploy/    # this profile directory
  data/      # PostgreSQL, Redis, RustFS, generated files
  backups/   # backup archives
```

The paths are configurable with `APP_DIR`, `DATA_DIR`, `BACKUP_DIR`, and `FRONTEND_DOCKERFILE` in `.env`.

## Files

```text
deploy/purefox/
  docker-compose.yml
  frontend.Dockerfile
  frontend-http.conf.template
  nginx.img.purefox.org.conf
  .env.example
  deploy.sh
  backup.sh
  README.md
```

## First Deploy

```bash
cd /srv/image2api/deploy
cp .env.example .env
chmod 600 .env
# Edit .env and set strong POSTGRES_PASSWORD, S3_ACCESS_KEY, S3_SECRET_KEY.
./deploy.sh
```

Install the host Nginx config manually:

```bash
sudo cp nginx.img.purefox.org.conf /etc/nginx/conf.d/img.purefox.org.conf
sudo nginx -t
sudo systemctl reload nginx
```

## Verification

```bash
docker compose --env-file .env -p image2api -f docker-compose.yml ps
curl http://127.0.0.1:18087/health
curl -k https://img.purefox.org/health
```

Expected host exposure: only `127.0.0.1:18087` from this stack. Public traffic should enter through host Nginx.

## Migration

Copy `/srv/image2api/app`, `/srv/image2api/deploy`, `/srv/image2api/data`, and `/srv/image2api/backups` to the target host. Restore the host Nginx config and wildcard certificate path, then run:

```bash
cd /srv/image2api/deploy
./deploy.sh
```

## Backup

```bash
cd /srv/image2api/deploy
./backup.sh
```

The backup archive contains `.env`, database dump, deployment templates, object/media data, Redis data, and Nginx config. Treat it as sensitive.

## Notes

RustFS runs as uid/gid `10001`; `deploy.sh` sets `$DATA_DIR/rustfs` ownership accordingly. Do not change it back to root-only.

# Purefox / img.purefox.org Deployment

This deployment profile runs image2api behind a host-level Nginx that already owns public `80/443` and TLS certificates.

It intentionally keeps the upstream one-command deployment separate:

- Keeps `web` in Docker, but exposes it only as HTTP on `127.0.0.1:18087`.
- Removes the `acme` sidecar and frontend container certificate scripts from this profile.
- Reuses the host wildcard certificate for `*.purefox.org`.
- Keeps PostgreSQL, Redis, RustFS, backend, and web on a private Docker network.
- Stores persistent data as bind mounts under `deploy/purefox/data/` for easier migration.

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
cd deploy/purefox
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

Copy this profile directory, including `.env`, `data/`, and `backups/`, to the target host. Restore the host Nginx config and wildcard certificate path, then run:

```bash
cd deploy/purefox
./deploy.sh
```

## Backup

```bash
cd deploy/purefox
./backup.sh
```

The backup archive contains `.env`, database dump, deployment templates, object/media data, Redis data, and Nginx config. Treat it as sensitive.

## Notes

RustFS runs as uid/gid `10001`; `deploy.sh` sets `data/rustfs` ownership accordingly. Do not change it back to root-only.

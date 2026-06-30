# Frontend is open-source: built from source inside the image, then served by
# nginx which also reverse-proxies the API and terminates TLS (certs from the
# acme.sh sidecar via a shared volume).
# ---- build stage ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# ---- serve stage ----
FROM nginx:1.27-alpine
# openssl: self-signed bootstrap cert. The nginx image substitutes ${DOMAIN} in
# /etc/nginx/templates/*.template at startup (limited to DOMAIN via the filter).
RUN apk add --no-cache openssl
COPY --from=build /app/dist /usr/share/nginx/html
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.d/10-selfsigned.sh /docker-entrypoint.d/10-selfsigned.sh
COPY docker-entrypoint.d/30-cert-watch.sh /docker-entrypoint.d/30-cert-watch.sh
RUN chmod +x /docker-entrypoint.d/10-selfsigned.sh /docker-entrypoint.d/30-cert-watch.sh
EXPOSE 80 443

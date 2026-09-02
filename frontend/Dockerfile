# syntax=docker/dockerfile:1
# Build the SPA, then serve it with nginx (which also proxies /api to the gateway).

FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.30.4-alpine
# Pin explicitly (not just `apk upgrade`) so Docker's build-layer cache busts
# whenever a known CVE needs a specific fixed version, instead of silently
# reusing a cached layer built before the fix existed.
RUN apk update && apk upgrade --no-cache && apk add --no-cache --upgrade "expat>=2.8.4-r0"
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080

# syntax=docker/dockerfile:1

ARG YYB_REPO=https://github.com/525815266/YYB-Go-Enhanced.git
ARG YYB_REF=dd0081ef393a3d3024b145dd038ea1192fdc00c5

FROM golang:1.23-alpine AS build

ARG YYB_REPO
ARG YYB_REF

RUN apk add --no-cache ca-certificates git

WORKDIR /src

# Pin the upstream revision so an Add-on version always builds reproducibly.
RUN git clone --filter=blob:none "${YYB_REPO}" . \
    && git checkout --detach "${YYB_REF}" \
    && test "$(git rev-parse HEAD)" = "${YYB_REF}"

RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/yyb-go \
    ./cmd/yyb-go

RUN mkdir -p /out/resource \
    && cp -R /src/resource/. /out/resource/

FROM nginx:1.27-alpine

RUN apk add --no-cache \
        apache2-utils \
        ca-certificates \
        curl \
        jq \
        su-exec \
    && addgroup -S yyb \
    && adduser -S -G yyb -h /app yyb \
    && mkdir -p /app/resource /etc/nginx/auth /run/nginx

WORKDIR /app

COPY --from=build /out/yyb-go /app/yyb-go
COPY --from=build /out/resource/ /app/resource/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY run.sh /run.sh

RUN chmod 0755 /app/yyb-go /run.sh \
    && find /app/resource -type d -exec chmod 0755 {} + \
    && find /app/resource -type f -exec chmod 0644 {} +

EXPOSE 8080 8000

ENTRYPOINT ["/run.sh"]

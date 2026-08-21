# syntax=docker/dockerfile:1

ARG YYB_REPO=https://github.com/525815266/YYB-Go-Enhanced.git
ARG YYB_REF=main

FROM golang:1.23-alpine AS build

ARG YYB_REPO
ARG YYB_REF

ENV GOPROXY=https://goproxy.cn,direct

RUN apk add --no-cache ca-certificates git

WORKDIR /src

# Copy addon config to invalidate docker cache when addon version changes
COPY config.json /tmp/addon_config.json

RUN echo "Building YYB-Go from ${YYB_REF}" \
    && cat /tmp/addon_config.json \
    && git clone --depth=1 --branch "${YYB_REF}" "${YYB_REPO}" . \
    && git rev-parse HEAD > /tmp/YYB_COMMIT

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/yyb-go \
    ./cmd/yyb-go

RUN mkdir -p /out/resource \
    && cp -R /src/resource/. /out/resource/ \
    && cp /tmp/YYB_COMMIT /out/YYB_COMMIT


FROM alpine:3.21

RUN apk add --no-cache \
        ca-certificates \
        curl \
        jq \
        su-exec \
    && addgroup -S yyb \
    && adduser -S -G yyb -h /app yyb

WORKDIR /app

COPY --from=build /out/yyb-go /app/yyb-go
COPY --from=build /out/resource/ /app/resource/
COPY --from=build /out/YYB_COMMIT /app/YYB_COMMIT
COPY run.sh /run.sh

RUN chmod 0755 /app/yyb-go /run.sh \
    && chown -R yyb:yyb /app/resource \
    && find /app/resource -type d -exec chmod 0755 {} + \
    && find /app/resource -type f -exec chmod 0644 {} +

EXPOSE 8000

ENTRYPOINT ["/run.sh"]

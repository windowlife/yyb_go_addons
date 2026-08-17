# syntax=docker/dockerfile:1

ARG YYB_REPO=https://github.com/525815266/YYB-Go-Enhanced.git
ARG YYB_REF=main

FROM golang:1.23-alpine AS build

ARG YYB_REPO
ARG YYB_REF

RUN apk add --no-cache ca-certificates git

WORKDIR /src

ENV GOPROXY=https://goproxy.cn,direct

# Build from the current upstream branch.
RUN git clone --depth=1 --branch "${YYB_REF}" "${YYB_REPO}" .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/yyb-go \
    ./cmd/yyb-go

RUN mkdir -p /out/resource \
    && cp -R /src/resource/. /out/resource/

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
COPY run.sh /run.sh

RUN chmod 0755 /app/yyb-go /run.sh \
    && chown -R yyb:yyb /app/resource \
    && find /app/resource -type d -exec chmod 0755 {} + \
    && find /app/resource -type f -exec chmod 0644 {} +

EXPOSE 8000

ENTRYPOINT ["/run.sh"]
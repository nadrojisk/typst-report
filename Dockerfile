## Report Typst backend image: pandoc + typst + fonts + this template.
##
## Usage:
##   docker build -t typst-report .
##   docker run --rm -v "$(pwd):/data" -w /data typst-report input.md -o output.pdf
##
## Build args:
##   TYPST_VERSION   — typst release tag to download (default: v0.15.1)
##   TIAGO_VERSION   — @preview/tiago package version to vendor (default: 0.1.0)

ARG TYPST_VERSION=v0.15.1
ARG TIAGO_VERSION=0.1.0

FROM alpine:3.21 AS typst-download
ARG TYPST_VERSION
RUN apk add --no-cache curl xz && \
    curl -fsSL "https://github.com/typst/typst/releases/download/${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
      | tar -xJ --strip-components=1 -C /usr/local/bin "typst-x86_64-unknown-linux-musl/typst" && \
    chmod +x /usr/local/bin/typst && typst --version

# Vendored so D2 diagrams render with no network access at compile time.
FROM alpine:3.21 AS tiago-download
ARG TIAGO_VERSION
RUN apk add --no-cache curl && \
    mkdir -p "/pkg/preview/tiago/${TIAGO_VERSION}" && \
    curl -fsSL "https://packages.typst.org/preview/tiago-${TIAGO_VERSION}.tar.gz" \
      | tar -xz -C "/pkg/preview/tiago/${TIAGO_VERSION}"

FROM pandoc/minimal:3.10.0-alpine
COPY --from=typst-download /usr/local/bin/typst /usr/local/bin/typst
COPY --from=tiago-download /pkg /root/.cache/typst/packages

# Bundled Inter (body) and JetBrains Mono (code), identical to local builds; DejaVu is the fallback.
RUN apk add --no-cache ttf-dejavu fontconfig
COPY fonts/*.ttf /usr/share/fonts/report/
RUN fc-cache -f

COPY report.typst           /usr/local/share/report/report.typst
COPY report-defaults.yaml   /usr/local/share/report/report-defaults.yaml
COPY filters/               /usr/local/share/report/filters/

ENTRYPOINT ["pandoc", \
  "--lua-filter=/usr/local/share/report/filters/report.lua", \
  "--template=/usr/local/share/report/report.typst", \
  "--pdf-engine=typst", \
  "--pdf-engine-opt=--font-path=/usr/share/fonts"]

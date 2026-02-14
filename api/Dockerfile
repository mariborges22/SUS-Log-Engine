# Estágio 1: Build da API Go
FROM golang:1.21-bookworm AS go-builder
WORKDIR /build
COPY api/go.mod api/go.sum ./
COPY api/ .
RUN go mod tidy
RUN go build -o main .

# Estágio 2: Build do Motor C++
FROM debian:bookworm-slim AS cpp-builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
COPY nexus-sus-engine/compiler.cpp .
RUN g++ -O3 compiler.cpp -o compiler -lpq

# Estágio 3: Runtime
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

RUN mkdir -p nexus-sus-engine
COPY --from=go-builder /build/main .
COPY --from=cpp-builder /build/compiler ./nexus-sus-engine/compiler
RUN chmod +x ./main ./nexus-sus-engine/compiler

EXPOSE 8080
CMD ["./main"]
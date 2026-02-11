# Estágio 1: Build da API Go
FROM golang:1.21-bookworm AS go-builder
WORKDIR /app
COPY api/go.mod api/go.sum ./
COPY api/ .
RUN go mod tidy
RUN go build -o main .

# Estágio 2: Build do Motor C++
FROM debian:bookworm AS cpp-builder
RUN apt-get update && apt-get install -y g++
WORKDIR /app
COPY nexus-sus-engine/ .
RUN g++ -O3 compiler.cpp -o compiler

# Estágio 3: Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libstdc++6 && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Cria a estrutura de pastas necessária para o path relativo do Go
RUN mkdir -p nexus-sus-engine

# Copia os binários mantendo a estrutura esperada pelo main.go
COPY --from=go-builder /app/main .
COPY --from=cpp-builder /app/compiler ./nexus-sus-engine/compiler

# Garante permissão de execução
RUN chmod +x ./main ./nexus-sus-engine/compiler

EXPOSE 8080
CMD ["./main"]
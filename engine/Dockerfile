FROM debian:bookworm-slim AS builder

# Instalação de dependências mínimas para compilação C++
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Compilação do binário focado em performance (-O3)
RUN g++ -O3 compiler.cpp -o engine_service

# Estágio 2: Runtime (Leve e estável com glibc)
FROM debian:bookworm-slim

WORKDIR /app
# Copia apenas o binário compilado do estágio anterior
COPY --from=builder /app/engine_service .

# Porta interna para comunicação com a API Go
EXPOSE 5000

CMD ["./engine_service"]

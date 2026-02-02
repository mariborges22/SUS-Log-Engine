# Estágio 1: Builder (Oficina de Alta Performance)
FROM debian:bookworm-slim AS builder

# Instalação das dependências de build e da LIBPQ para o Postgres
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Copiamos apenas os arquivos necessários para evitar carregar o JSON bruto
COPY compiler.cpp .

# Compilação com otimização máxima (-O3) e linkagem do Postgres (-lpq)
# O uso de malloc() e a estrutura de Tabela Hash no código garantem a busca O(1) [1]
RUN g++ -O3 compiler.cpp -o engine_service -lpq

# Estágio 2: Runtime (Leve e Sustentável)
FROM debian:bookworm-slim

# Instalamos apenas a libpq5 (runtime) para o binário funcionar
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Copia apenas o binário "enxuto" do estágio anterior
COPY --from=builder /app/engine_service .

# Porta de comunicação com a API Go
EXPOSE 5000

CMD ["./engine_service"]

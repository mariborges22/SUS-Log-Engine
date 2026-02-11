# Estágio 1: Build da API Go
FROM golang:1.21-bookworm AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

# Estágio 2: Runtime
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=builder /app/main .

EXPOSE 8080
CMD ["./main"]
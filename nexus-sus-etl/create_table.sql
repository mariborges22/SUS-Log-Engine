-- Tabela Otimizada para Indicadores do SUS
-- Engine: PostgreSQL 15.10 + PostGIS

CREATE TABLE IF NOT EXISTS indicadores_sus (
    -- DADOS GEOGRÁFICOS E HIERÁRQUICOS
    estado VARCHAR(50) NOT NULL,           -- Nome do Estado (ex: "Amazonas")
    regiao VARCHAR(20) NOT NULL,           -- Nome da Região (ex: "Norte")
    
    -- METRICAS (FLOAT para cálculos estatísticos, mas poderia ser NUMERIC(18,2) dependendo da precisão)
    vl_uf FLOAT,                   -- Valor do indicador no Estado
    vl_regiao FLOAT,               -- Valor do indicador na Região
    vl_brasil FLOAT,               -- Valor do indicador no Brasil
    
    -- TEMPORALIDADE
    dt_competencia DATE NOT NULL,          -- Mês de competência do dado (Critical for Time Series)
    dt_atualizacao DATE DEFAULT CURRENT_DATE, -- Data de carga/atualização
    
    -- Constraint de Unicidade (Evita duplicatas de processamento)
    PRIMARY KEY (estado, dt_competencia)
);

-- ÍNDICES PARA PERFORMANCE O(1) / O(log N)
-- Índice para filtragem rápida por região (Dashboard Regional)
CREATE INDEX IF NOT EXISTS idx_regiao ON indicadores_sus (regiao);

-- Índice para séries temporais (Dashboard de Evolução)
CREATE INDEX IF NOT EXISTS idx_competencia ON indicadores_sus (dt_competencia);

-- Comentários para Documentação do Schema
COMMENT ON TABLE indicadores_sus IS 'Armazena indicadores de saúde do SUS agregados por UF e Região';
COMMENT ON COLUMN indicadores_sus.estado IS 'Unidade Federativa (UF) do indicador';
COMMENT ON COLUMN indicadores_sus.dt_competencia IS 'Referência temporal do indicador (primeiro dia do mês)';

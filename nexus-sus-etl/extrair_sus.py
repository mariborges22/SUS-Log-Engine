import json
import logging
import os
import sys
import time
from datetime import datetime
from urllib.parse import quote_plus

import boto3
from botocore.exceptions import ClientError
from sqlalchemy import create_engine, text

# Configuração de Logging Centralizado
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - [%(levelname)s] - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)

# Configurações de Ambiente (Fail-Fast)
try:
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
    S3_BUCKET = os.environ["S3_BUCKET_NAME"]
    S3_KEY = os.getenv("S3_KEY", "dados_brutos.json")

    DB_HOST = os.environ["DB_HOST"]
    DB_NAME = os.environ["DB_NAME"]
    DB_USER = os.environ["DB_USER"]
    DB_PASSWORD = os.environ["DB_PASSWORD"]
except KeyError as e:
    logger.error(f"Variável de ambiente obrigatória não encontrada: {e}")
    sys.exit(1)


# Retry Decorator Manual
def retry_operation(max_retries=3, delay=2):
    def decorator(func):
        def wrapper(*args, **kwargs):
            retries = 0
            while retries < max_retries:
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    retries += 1
                    wait = delay * (2 ** (retries - 1))
                    logger.warning(
                        f"Erro na tentativa {retries}/{max_retries}: {e}. Tentando novamente em {wait}s..."
                    )
                    time.sleep(wait)
            logger.error(f"Falha crítica após {max_retries} tentativas.")
            raise Exception("Max retries exceeded")

        return wrapper

    return decorator


@retry_operation(max_retries=3, delay=2)
def extract_from_s3() -> list:
    """
    Baixa o arquivo JSON do S3 e retorna como lista de dicts.
    """
    logger.info(f"Iniciando extração do S3: s3://{S3_BUCKET}/{S3_KEY}")

    s3_client = boto3.client("s3", region_name=AWS_REGION)

    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=S3_KEY)
        json_content = response["Body"].read().decode("utf-8")
        data = json.loads(json_content)

        if isinstance(data, dict):
            data = [data]

        logger.info(f"Extração concluída. Rows: {len(data)}")
        return data

    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            logger.error("O arquivo não foi encontrado no S3.")
        else:
            logger.error(f"Erro AWS S3: {e}")
        raise


def _safe_float(value):
    """Converte valor para float com fallback 0.0."""
    try:
        return float(value) if value is not None else 0.0
    except (ValueError, TypeError):
        return 0.0


def _safe_date(value):
    """Converte valor para date string (YYYY-MM-DD) com fallback None."""
    if value is None:
        return None
    try:
        if isinstance(value, str):
            # Tenta vários formatos
            for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%d/%m/%Y"):
                try:
                    return datetime.strptime(value, fmt).strftime("%Y-%m-%d")
                except ValueError:
                    continue
        return str(value)[:10]
    except Exception:
        return None


def transform_data(raw_data: list) -> list:
    """
    Aplica regras de negócio, renomeia colunas e valida tipos.
    Sem pandas — usa Python puro.
    """
    logger.info("Iniciando Transformação de Dados...")

    if not raw_data:
        logger.warning("Dados vazios. Nada para transformar.")
        return []

    # 1. Mapeamento JSON -> SQL
    rename_map = {
        "no_uf": "estado",
        "no_regiao_brasil": "regiao",
        "vl_indicador_calculado_uf": "vl_uf",
        "vl_indicador_calculado_reg": "vl_regiao",
        "vl_indicador_calculado_br": "vl_brasil",
        "dt_competencia": "dt_competencia",
        "dt_atualizacao": "dt_atualizacao",
    }

    transformed = []
    for row in raw_data:
        record = {}
        for json_key, sql_key in rename_map.items():
            record[sql_key] = row.get(json_key)

        # 2. Conversão de tipos
        record["vl_uf"] = _safe_float(record["vl_uf"])
        record["vl_regiao"] = _safe_float(record["vl_regiao"])
        record["vl_brasil"] = _safe_float(record["vl_brasil"])
        record["dt_competencia"] = _safe_date(record["dt_competencia"])
        record["dt_atualizacao"] = _safe_date(record["dt_atualizacao"])

        # 3. Validação de Nulos Críticos
        if record["estado"] and record["dt_competencia"]:
            transformed.append(record)

    # 4. Deduplicação (estado + dt_competencia, keep last)
    seen = {}
    for record in transformed:
        key = (record["estado"], record["dt_competencia"])
        seen[key] = record  # Sobrescreve = keep last

    deduped = list(seen.values())

    if len(transformed) > len(deduped):
        logger.info(f"Removidas {len(transformed) - len(deduped)} duplicatas.")

    logger.info(f"Transformação concluída. {len(deduped)} registros válidos.")
    return deduped


def load_to_rds(records: list):
    """
    Carrega dados no PostgreSQL usando SQLAlchemy e UPSERT.
    """
    logger.info("Iniciando Carga no RDS (PostgreSQL)...")

    if not records:
        logger.info("Nada para carregar.")
        return

    db_url = (
        f"postgresql+psycopg2://{DB_USER}:{quote_plus(DB_PASSWORD)}@"
        f"{DB_HOST}:5432/{DB_NAME}?sslmode=require"
    )

    engine = create_engine(
        db_url,
        pool_size=5,
        max_overflow=2,
        pool_timeout=30,
        pool_recycle=1800,
    )

    # Garantir Schema
    try:
        with open("create_table.sql", "r") as f:
            ddl_sql = f.read()
            with engine.begin() as conn:
                conn.execute(text(ddl_sql))
            logger.info("Schema garantido com sucesso (DDL executado).")
    except Exception as e:
        logger.warning(f"Erro ao tentar executar DDL (pode já existir): {e}")

    upsert_sql = text("""
        INSERT INTO indicadores_sus (estado, regiao, vl_uf, vl_regiao, vl_brasil, dt_competencia, dt_atualizacao)
        VALUES (:estado, :regiao, :vl_uf, :vl_regiao, :vl_brasil, :dt_competencia, :dt_atualizacao)
        ON CONFLICT (estado, dt_competencia) 
        DO UPDATE SET
            vl_uf = EXCLUDED.vl_uf,
            vl_regiao = EXCLUDED.vl_regiao,
            vl_brasil = EXCLUDED.vl_brasil,
            dt_atualizacao = EXCLUDED.dt_atualizacao;
    """)

    # Batch Insert (500 rows por vez)
    batch_size = 500
    total_rows = len(records)

    with engine.begin() as conn:
        for i in range(0, total_rows, batch_size):
            batch = records[i : i + batch_size]
            try:
                conn.execute(upsert_sql, batch)
                logger.info(f"Batch {i//batch_size + 1} processado ({len(batch)} rows)")
            except Exception as e:
                logger.error(f"Erro no batch {i}: {e}")
                raise

    logger.info(f"Carga concluída! Total processado: {total_rows} registros.")


def lambda_handler(event, context):
    """
    AWS Lambda Handler Entry Point
    """
    logger.info("=== INICIANDO PIPELINE ETL NEXUS-SUS (LAMBDA) ===")
    start_time = time.time()

    try:
        # Step 1: Extract
        raw_data = extract_from_s3()

        # Step 2: Transform
        clean_data = transform_data(raw_data)

        # Step 3: Load
        load_to_rds(clean_data)

        elapsed = time.time() - start_time
        logger.info(f"=== PIPELINE FINALIZADO COM SUCESSO em {elapsed:.2f}s ===")

        return {
            "statusCode": 200,
            "body": f"ETL Success. Processed {len(clean_data)} records in {elapsed:.2f}s",
        }

    except Exception as e:
        logger.critical(f"Pipeline falhou: {e}")
        raise e

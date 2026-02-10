import boto3
import pandas as pd
from sqlalchemy import create_engine, text
import os
import logging
import sys
import time
from urllib.parse import quote_plus
from io import StringIO
from botocore.exceptions import ClientError, NoCredentialsError

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
    S3_BUCKET = os.environ["S3_BUCKET_NAME"]  # Nome do bucket production/staging
    S3_KEY = os.getenv("S3_KEY", "dados_brutos.json")  # Caminho do arquivo

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
                    wait = delay * (2 ** (retries - 1))  # Backoff Exponencial
                    logger.warning(
                        f"Erro na tentativa {retries}/{max_retries}: {e}. Tentando novamente em {wait}s..."
                    )
                    time.sleep(wait)
            logger.error(f"Falha crítica após {max_retries} tentativas.")
            raise Exception("Max retries exceeded")

        return wrapper

    return decorator


@retry_operation(max_retries=3, delay=2)
def extract_from_s3() -> pd.DataFrame:
    """
    Baixa o arquivo JSON do S3 e carrega em um DataFrame Pandas.
    Complexidade: O(N) leitura do stream.
    """
    logger.info(f"Iniciando extração do S3: s3://{S3_BUCKET}/{S3_KEY}")

    s3_client = boto3.client("s3", region_name=AWS_REGION)

    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=S3_KEY)
        json_content = response["Body"].read().decode("utf-8")

        # Carregar JSON
        # df = pd.read_json(StringIO(json_content))
        # Note: Depending on the JSON structure, read_json behavior might vary.
        # StringIO is correct for text streams.
        df = pd.read_json(StringIO(json_content))

        logger.info(f"Extração concluída. Rows: {len(df)}")
        return df

    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            logger.error("O arquivo não foi encontrado no S3.")
        else:
            logger.error(f"Erro AWS S3: {e}")
        raise


def transform_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Aplica regras de negócio, renomeia colunas e valida tipos.
    """
    logger.info("Iniciando Transformação de Dados...")

    if df.empty:
        logger.warning("DataFrame vazio. Nada para transformar.")
        return df

    # 1. Renomear Colunas (Mapeamento JSON -> SQL)
    rename_map = {
        "no_uf": "estado",
        "no_regiao_brasil": "regiao",
        "vl_indicador_calculado_uf": "vl_uf",
        "vl_indicador_calculado_reg": "vl_regiao",
        "vl_indicador_calculado_br": "vl_brasil",
        "dt_competencia": "dt_competencia",
        "dt_atualizacao": "dt_atualizacao",
    }

    df_transformed = df.rename(columns=rename_map)[list(rename_map.values())]

    # 2. Conversão de Tipos
    # Converter datas
    df_transformed["dt_competencia"] = pd.to_datetime(
        df_transformed["dt_competencia"]
    ).dt.date
    df_transformed["dt_atualizacao"] = pd.to_datetime(
        df_transformed["dt_atualizacao"]
    ).dt.date

    # Converter valores numéricos (garantir float)
    numeric_cols = ["vl_uf", "vl_regiao", "vl_brasil"]
    for col in numeric_cols:
        df_transformed[col] = (
            pd.to_numeric(df_transformed[col], errors="coerce").fillna(0.0).astype(float)
        )

    # 3. Remover Duplicatas (Regra de Negócio: Estado + Competência deve ser único)
    initial_rows = len(df_transformed)
    df_transformed = df_transformed.drop_duplicates(
        subset=["estado", "dt_competencia"], keep="last"
    )
    if len(df_transformed) < initial_rows:
        logger.info(f"Removidas {initial_rows - len(df_transformed)} duplicatas.")

    # 4. Validação de Nulos Críticos
    if (
        df_transformed["estado"].isnull().any()
        or df_transformed["dt_competencia"].isnull().any()
    ):
        logger.error("Dados críticos (estado ou data) nulos encontrados!")
        raise ValueError("Critical null values detected")

    logger.info("Transformação concluída com sucesso.")
    return df_transformed


def load_to_rds(df: pd.DataFrame):
    """
    Carrega dados no PostgreSQL usando SQLAlchemy e UPSERT (INSERT ON CONFLICT).
    Segurança: Prepared Statements via Engine.
    """
    logger.info("Iniciando Carga no RDS (PostgreSQL)...")

    if df.empty:
        logger.info("Nada para carregar.")
        return

    # Connection String Segura (URL Encoded)
    db_url = (
        f"postgresql+psycopg2://{DB_USER}:{quote_plus(DB_PASSWORD)}@"
        f"{DB_HOST}:5432/{DB_NAME}?sslmode=require"
    )

    engine = create_engine(
        db_url,
        pool_size=5,  # Max conexões simultâneas
        max_overflow=2,  # Overflow permitido
        pool_timeout=30,  # Timeout para pegar conexão
        pool_recycle=1800,  # Reciclar conexões antigas
    )

    # 0. Garantir Schema (Self-Healing)
    # Como não conseguimos rodar psql externo, a Lambda cria a tabela se não existir
    try:
        with open("create_table.sql", "r") as f:
            ddl_sql = f.read()
            with engine.begin() as conn:
                conn.execute(text(ddl_sql))
            logger.info("Schema garantido com sucesso (DDL executado).")
    except Exception as e:
        logger.warning(f"Erro ao tentar executar DDL (pode já existir): {e}")

    upsert_sql = text(
        """
        INSERT INTO indicadores_sus (estado, regiao, vl_uf, vl_regiao, vl_brasil, dt_competencia, dt_atualizacao)
        VALUES (:estado, :regiao, :vl_uf, :vl_regiao, :vl_brasil, :dt_competencia, :dt_atualizacao)
        ON CONFLICT (estado, dt_competencia) 
        DO UPDATE SET
            vl_uf = EXCLUDED.vl_uf,
            vl_regiao = EXCLUDED.vl_regiao,
            vl_brasil = EXCLUDED.vl_brasil,
            dt_atualizacao = EXCLUDED.dt_atualizacao;
    """
    )

    # Batch Insert (500 rows por vez)
    batch_size = 500
    rows = df.to_dict(orient="records")
    total_rows = len(rows)

    with engine.begin() as conn:  # Transaction Scope (Auto Commit/Rollback)
        for i in range(0, total_rows, batch_size):
            batch = rows[i : i + batch_size]
            try:
                conn.execute(upsert_sql, batch)
                logger.info(f"Batch {i//batch_size + 1} processado ({len(batch)} rows)")
            except Exception as e:
                logger.error(f"Erro no batch {i}: {e}")
                raise  # Transaction will rollback

    logger.info(f"Carga concluída! Total processado: {total_rows} registros.")


def lambda_handler(event, context):
    """
    AWS Lambda Handler Entry Point
    """
    logger.info("=== INICIANDO PIPELINE ETL NEXUS-SUS (LAMBDA) ===")
    start_time = time.time()

    try:
        # Step 1: Extract
        df_raw = extract_from_s3()

        # Step 2: Transform
        df_clean = transform_data(df_raw)

        # Step 3: Load
        load_to_rds(df_clean)

        elapsed = time.time() - start_time
        logger.info(f"=== PIPELINE FINALIZADO COM SUCESSO em {elapsed:.2f}s ===")

        return {
            "statusCode": 200,
            "body": f"ETL Success. Processed {len(df_clean)} records in {elapsed:.2f}s",
        }

    except Exception as e:
        logger.critical(f"Pipeline falhou: {e}")
        # Lambda deve levantar exceção para ser marcada como erro no CloudWatch
        raise e

# ==============================================================================
# TERRAFORM IMPORT BLOCKS
# Estes blocos permitem que o Terraform "assuma" o controle de recursos que
# já existem na AWS sem tentar recriá-los e dar erro de 'AlreadyExists'.
# Os IDs são dinâmicos para suportar Staging e Produção.
# ==============================================================================

# 1. ECR Repositories
import {
  to = aws_ecr_repository.repos["nexus-sus-api"]
  id = "nexus-sus-api-${var.environment}"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-frontend"]
  id = "nexus-sus-frontend-${var.environment}"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-engine"]
  id = "nexus-sus-engine-${var.environment}"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-etl"]
  id = "nexus-sus-etl-${var.environment}"
}

# 2. IAM Roles
import {
  to = aws_iam_role.ecs_task_execution_role
  id = "${var.project_name}-ecs-task-execution-role-${var.environment}"
}

import {
  to = aws_iam_role.ecs_task_role
  id = "${var.project_name}-ecs-task-role-${var.environment}"
}

import {
  to = aws_iam_role.etl_role
  id = "${var.project_name}-etl-role-${var.environment}"
}

# 3. IAM Policies (ARN fixo por conta do ID da conta)
import {
  to = aws_iam_policy.ecs_logging
  id = "arn:aws:iam::629614691528:policy/nexus-sus-ecs-logging-policy-${var.environment}"
}

# 4. S3 Buckets
import {
  to = aws_s3_bucket.data_lake
  id = "nexus-sus-data-lake-${var.environment}"
}

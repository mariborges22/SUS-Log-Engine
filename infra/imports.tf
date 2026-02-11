# ==============================================================================
# TERRAFORM IMPORT BLOCKS
# Estes blocos permitem que o Terraform "assuma" o controle de recursos que
# já existem na AWS sem tentar recriá-los e dar erro de 'AlreadyExists'.
# ==============================================================================

# 1. ECR Repositories
import {
  to = aws_ecr_repository.repos["nexus-sus-api"]
  id = "nexus-sus-api-staging"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-frontend"]
  id = "nexus-sus-frontend-staging"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-engine"]
  id = "nexus-sus-engine-staging"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-etl"]
  id = "nexus-sus-etl-staging"
}

# 2. IAM Roles
import {
  to = aws_iam_role.ecs_task_execution_role
  id = "nexus-sus-ecs-task-execution-role-staging"
}

import {
  to = aws_iam_role.ecs_task_role
  id = "nexus-sus-ecs-task-role-staging"
}

# 3. IAM Policies
# Nota: Para Policies, o ID é o ARN. Substituiremos o número da conta via account_id.
import {
  to = aws_iam_policy.ecs_logging
  id = "arn:aws:iam::629614691528:policy/nexus-sus-ecs-logging-policy-staging"
}

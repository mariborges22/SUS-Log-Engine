# ==============================================================================
# TERRAFORM IMPORT BLOCKS (COMETADOS)
# Desativado para evitar erros de sintaxe com variáveis nos IDs.
# Use 'terraform import' via CLI se necessário.
# ==============================================================================

/*
import {
  to = aws_ecr_repository.repos["nexus-sus-api"]
  id = "nexus-sus-api-${var.environment}"
}

import {
  to = aws_ecr_repository.repos["nexus-sus-frontend"]
  id = "nexus-sus-frontend-${var.environment}"
}
...
*/

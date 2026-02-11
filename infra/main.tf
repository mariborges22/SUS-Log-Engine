# ==============================================================================
# GLOBAL DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}

# Adicionalmente, garantindo que o baseline regional esteja disponível
data "aws_region" "current" {}

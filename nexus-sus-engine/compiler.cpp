#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Definição do tamanho da tabela hash (número primo maior para produção)
#define TABLE_SIZE 4999

// 1. Estrutura de Dados (struct node)
struct node {
  char estado[3]; // Chave principal (ex: "SP", "RJ")
  char regiao[50];
  double vl_uf;
  double vl_regiao;
  double vl_brasil;
  char dt_competencia[15];
  char dt_atualizacao[15];
  struct node *next; // Ponteiro para gerenciar colisões (Separate Chaining)
};

// Tabela Hash global (array de ponteiros)
struct node *hashTable[TABLE_SIZE];

// Inicializa a tabela hash com NULL
void init_table() {
  for (int i = 0; i < TABLE_SIZE; i++) {
    hashTable[i] = NULL;
  }
}

// 2. Função Hash (DJB2 adaptada para performance e baixa colisão)
unsigned int hash_function(const char *key) {
  unsigned int hash = 5381;
  int c;
  while ((c = *key++)) {
    hash = ((hash << 5) + hash) + c; // hash * 33 + c
  }
  return hash % TABLE_SIZE;
}

// 3. Alocação Dinâmica e Segurança
struct node *create_node(const char *estad, const char *reg, double v_uf,
                         double v_reg, double v_br, const char *competencia,
                         const char *atualizacao) {
  struct node *new_node = (struct node *)malloc(sizeof(struct node));

  if (new_node == NULL) {
    fprintf(stderr, "{\"error\": \"Falha na alocacao de memoria\"}\n");
    return NULL;
  }

  strncpy(new_node->estado, estad, sizeof(new_node->estado) - 1);
  new_node->estado[sizeof(new_node->estado) - 1] = '\0';

  strncpy(new_node->regiao, reg, sizeof(new_node->regiao) - 1);
  new_node->regiao[sizeof(new_node->regiao) - 1] = '\0';

  new_node->vl_uf = v_uf;
  new_node->vl_regiao = v_reg;
  new_node->vl_brasil = v_br;

  strncpy(new_node->dt_competencia, competencia,
          sizeof(new_node->dt_competencia) - 1);
  new_node->dt_competencia[sizeof(new_node->dt_competencia) - 1] = '\0';

  strncpy(new_node->dt_atualizacao, atualizacao,
          sizeof(new_node->dt_atualizacao) - 1);
  new_node->dt_atualizacao[sizeof(new_node->dt_atualizacao) - 1] = '\0';

  new_node->next = NULL;

  return new_node;
}

// 2. Separate Chaining (Inserção)
void insert_node(const char *estado, const char *regiao, double vl_uf,
                 double vl_regiao, double vl_brasil, const char *dt_comp,
                 const char *dt_atual) {
  unsigned int index = hash_function(estado);
  struct node *new_node =
      create_node(estado, regiao, vl_uf, vl_regiao, vl_brasil, dt_comp, dt_atual);

  if (new_node == NULL)
    return;

  // Inserção no início da lista para O(1)
  new_node->next = hashTable[index];
  hashTable[index] = new_node;
}

// Busca (O(1) médio com Separate Chaining)
struct node *search_node(const char *estado_key) {
  unsigned int index = hash_function(estado_key);
  struct node *current = hashTable[index];

  while (current != NULL) {
    if (strcmp(current->estado, estado_key) == 0) {
      return current;
    }
    current = current->next;
  }
  return NULL;
}

// 4. Gestão de Memória (Higiene de hardware limitado 512MB)
void cleanup_table() {
  for (int i = 0; i < TABLE_SIZE; i++) {
    struct node *current = hashTable[i];
    while (current != NULL) {
      struct node *temp = current;
      current = current->next;
      free(temp);
    }
    hashTable[i] = NULL;
  }
}

// Motor CLI via Pipe (stdin)
int main() {
  init_table();

  char command[10];
  char uf[5], regiao[50], comp[20], atual[20];
  double v_uf, v_reg, v_br;

  // Loop de comandos:
  // L <UF> <REGIAO> <V_UF> <V_REG> <V_BR> <COMPETENCIA> <ATUALIZACAO> (Load)
  // Q <UF> (Query)
  // X (Exit)
  while (scanf("%s", command) != EOF) {
    if (strcmp(command, "L") == 0) {
      if (scanf("%s %s %lf %lf %lf %s %s", uf, regiao, &v_uf, &v_reg, &v_br,
                comp, atual) == 7) {
        insert_node(uf, regiao, v_uf, v_reg, v_br, comp, atual);
      }
    } else if (strcmp(command, "Q") == 0) {
      if (scanf("%s", uf) == 1) {
        struct node *res = search_node(uf);
        if (res != NULL) {
          printf("{\"status\": \"success\", \"data\": {\"estado\": \"%s\", "
                 "\"regiao\": \"%s\", \"vl_uf\": %.2f, \"vl_regiao\": %.2f, "
                 "\"vl_brasil\": %.2f, \"dt_competencia\": \"%s\", "
                 "\"dt_atualizacao\": \"%s\"}}\n",
                 res->estado, res->regiao, res->vl_uf, res->vl_regiao,
                 res->vl_brasil, res->dt_competencia, res->dt_atualizacao);
        } else {
          printf("{\"status\": \"not_found\", \"uf\": \"%s\"}\n", uf);
        }
        fflush(stdout); // Garante que a API Go receba imediatamente
      }
    } else if (strcmp(command, "X") == 0) {
      break;
    }
  }

  cleanup_table();
  return 0;
}



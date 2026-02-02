#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Definição do tamanho da tabela hash (número primo para minimizar colisões)
#define TABLE_SIZE 101

// 1. Estrutura de Dados (struct node)
struct node {
    char estado[3];          // Chave principal (ex: "SP", "RJ")
    char regiao[20];
    double vl_uf;
    double vl_regiao;
    double vl_brasil;
    char dt_competencia[10];
    char dt_atualizacao[10];
    struct node *next;       // Ponteiro para gerenciar colisões
};

// Tabela Hash global (array de ponteiros)
struct node* hashTable[TABLE_SIZE];

// Inicializa a tabela hash com NULL
void init_table() {
    for (int i = 0; i < TABLE_SIZE; i++) {
        hashTable[i] = NULL;
    }
}

// 2. Função Hash (Simples baseada em strings)
unsigned int hash_function(const char *key) {
    unsigned int hash = 0;
    while (*key) {
        hash = (hash << 5) + *key++; // hash * 33 + c
    }
    return hash % TABLE_SIZE;
}

// 3. Alocação Dinâmica e Segurança
struct node* create_node(const char *estad, const char *reg, double v_uf, double v_reg, double v_br, const char *competencia, const char *atualizacao) {
    // Alocação manual
    struct node* new_node = (struct node*) malloc(sizeof(struct node));
    
    // Verificação de erro na alocação
    if (new_node == NULL) {
        fprintf(stderr, "Erro critico: Falha na alocacao de memoria (malloc retornou NULL)\n");
        return NULL;
    }

    // Copia dos dados com segurança (strncpy para evitar buffer overflow)
    strncpy(new_node->estado, estad, sizeof(new_node->estado) - 1);
    new_node->estado[sizeof(new_node->estado) - 1] = '\0';

    strncpy(new_node->regiao, reg, sizeof(new_node->regiao) - 1);
    new_node->regiao[sizeof(new_node->regiao) - 1] = '\0';

    new_node->vl_uf = v_uf;
    new_node->vl_regiao = v_reg;
    new_node->vl_brasil = v_br;

    strncpy(new_node->dt_competencia, competencia, sizeof(new_node->dt_competencia) - 1);
    new_node->dt_competencia[sizeof(new_node->dt_competencia) - 1] = '\0';

    strncpy(new_node->dt_atualizacao, atualizacao, sizeof(new_node->dt_atualizacao) - 1);
    new_node->dt_atualizacao[sizeof(new_node->dt_atualizacao) - 1] = '\0';

    new_node->next = NULL;

    return new_node;
}

// 2. Separate Chaining (Inserção)
void insert_node(const char *estado, const char *regiao, double vl_uf, double vl_regiao, double vl_brasil, const char *dt_comp, const char *dt_atual) {
    unsigned int index = hash_function(estado);
    struct node* new_node = create_node(estado, regiao, vl_uf, vl_regiao, vl_brasil, dt_comp, dt_atual);

    if (new_node == NULL) return; // Falha na alocação tratada

    // Inserção no início da lista (O(1))
    new_node->next = hashTable[index];
    hashTable[index] = new_node;
    
    // Debug opcional
    // printf("Inserido %s no indice %u\n", estado, index);
}

// Busca (O(1) médio)
struct node* search_node(const char *estado_key) {
    unsigned int index = hash_function(estado_key);
    struct node* current = hashTable[index];

    while (current != NULL) {
        if (strcmp(current->estado, estado_key) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

// 4. Gestão de Memória (Garbage Collection Manual)
void cleanup_table() {
    printf("Iniciando limpeza da tabela hash...\n");
    int freed_nodes = 0;
    for (int i = 0; i < TABLE_SIZE; i++) {
        struct node* current = hashTable[i];
        while (current != NULL) {
            struct node* temp = current;
            current = current->next;
            free(temp); // Devolve memória à AVAIL List
            freed_nodes++;
        }
        hashTable[i] = NULL;
    }
    printf("Limpeza concluida. Nos liberados: %d\n", freed_nodes);
}

// Função main para demonstrar o carreg e busca
int main() {
    init_table();

    printf("=== Carregando Tabela Hash ===\n");
    
    // Inserindo dados de teste
    insert_node("SP", "Sudeste", 150.50, 140.20, 130.00, "202310", "20231101");
    insert_node("RJ", "Sudeste", 145.30, 140.20, 130.00, "202310", "20231101");
    insert_node("MG", "Sudeste", 135.00, 140.20, 130.00, "202310", "20231101");
    insert_node("BA", "Nordeste", 120.10, 115.50, 130.00, "202310", "20231101");
    insert_node("AM", "Norte", 160.00, 155.00, 130.00, "202310", "20231101");

    // Simulando colisão hipotética (dependendo da função hash e tamanho, pode ocorrer)
    // insert_node("XX", ...) 

    printf("=== Teste de Busca (O(1)) ===\n");
    
    // Busca 1: Encontrado
    const char* targets[] = {"SP", "BA", "RS"}; // RS não existe
    for (int i = 0; i < 3; i++) {
        struct node* res = search_node(targets[i]);
        if (res != NULL) {
            printf("[ENCONTRADO] Estado: %s | Regiao: %s | Valor UF: %.2f\n", 
                   res->estado, res->regiao, res->vl_uf);
        } else {
            printf("[NAO ENCONTRADO] Estado: %s\n", targets[i]);
        }
    }

    // 5. Simplicidade e Garbage Collection
    cleanup_table();

    return 0;
}

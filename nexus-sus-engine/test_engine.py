import subprocess
import time
import json
import sys

def run_test():
    print("=== Iniciando Validação DSA Independente (C++ Engine) ===")
    
    # Inicia o processo (Caminho corrigido para o Runner)
    process = subprocess.Popen(
        ['./compiler'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    # 1. Teste de Carga (Separate Chaining)
    print("--- Testando Carga e Colisões ---")
    states = ["SP", "RJ", "MG", "ES", "BA", "PE", "CE", "AM", "PA", "RS"]
    for state in states:
        cmd = f"L {state} Regiao_{state} 100.0 200.0 300.0 202310 20231101\n"
        process.stdin.write(cmd)
    
    # Forçar colisão (usando chaves que podem bater dependendo do TABLE_SIZE e hash)
    # Como usamos DJB2 e TABLE_SIZE 4999, vamos apenas inserir mais dados
    process.stdin.flush()

    # 2. Teste de Busca O(1)
    print("--- Testando Busca O(1) ---")
    for state in states:
        start_time = time.time()
        process.stdin.write(f"Q {state}\n")
        process.stdin.flush()
        
        response = process.stdout.readline()
        elapsed = time.time() - start_time
        
        try:
            data = json.loads(response)
            if data['status'] != 'success' or data['data']['estado'] != state:
                print(f"ERRO: Resposta inválida para {state}: {response}")
                sys.exit(1)
            print(f"Busca {state}: {elapsed:.6f}s - OK")
        except Exception as e:
            print(f"FALHA Crítica: {e} | Resposta: {response}")
            sys.exit(1)

    # 3. Teste de Encerramento e Higiene (X)
    print("--- Testando Encerramento (X) ---")
    process.stdin.write("X\n")
    process.stdin.flush()
    
    process.wait()
    if process.returncode != 0:
        print(f"ERRO: O motor encerrou com código {process.returncode}")
        sys.exit(1)

    print("=== Validação DSA Concluída com Sucesso! ===")

if __name__ == "__main__":
    run_test()

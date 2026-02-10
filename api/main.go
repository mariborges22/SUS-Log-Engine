package main

import (
	"bufio"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"

	_ "github.com/lib/pq"
)

// Indicador representa os dados buscados no RDS
type Indicador struct {
	Estado         string  `json:"estado"`
	Regiao         string  `json:"regiao"`
	VlUF           float64 `json:"vl_uf"`
	VlRegiao       float64 `json:"vl_regiao"`
	VlBrasil       float64 `json:"vl_brasil"`
	DtCompetencia  string  `json:"dt_competencia"`
	DtAtualizacao  string  `json:"dt_atualizacao"`
}

var (
	engineStdin  io.WriteCloser
	engineStdout *bufio.Scanner
)

func initEngine() {
	// Caminho para o binário C++ (ajustar conforme o ambiente)
	cmd := exec.Command("./nexus-sus-engine/compiler")
	
	var err error
	engineStdin, err = cmd.StdinPipe()
	if err != nil {
		log.Fatal("Falha ao abrir stdin do engine:", err)
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal("Falha ao abrir stdout do engine:", err)
	}
	engineStdout = bufio.NewScanner(stdout)

	if err := cmd.Start(); err != nil {
		log.Fatal("Falha ao iniciar engine C++:", err)
	}

	log.Println("Engine C++ iniciado e aguardando comandos.")
}

func loadFromDB() {
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Println("Erro ao conectar ao DB:", err)
		return
	}
	defer db.Close()

	rows, err := db.Query("SELECT estado, regiao, valor_uf, valor_regiao, valor_brasil, dt_competencia, dt_atualizacao FROM indicadores_sus")
	if err != nil {
		log.Println("Erro ao buscar indicadores:", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var ind Indicador
		if err := rows.Scan(&ind.Estado, &ind.Regiao, &ind.VlUF, &ind.VlRegiao, &ind.VlBrasil, &ind.DtCompetencia, &ind.DtAtualizacao); err != nil {
			log.Println("Erro ao escanear linha:", err)
			continue
		}

		// Injeta no C++ via L (Load)
		// Formato: L <UF> <REGIAO> <V_UF> <V_REG> <V_BR> <COMPETENCIA> <ATUALIZACAO>
		fmt.Fprintf(engineStdin, "L %s %s %.2f %.2f %.2f %s %s\n",
			ind.Estado, strings.ReplaceAll(ind.Regiao, " ", "_"), ind.VlUF, ind.VlRegiao, ind.VlBrasil, ind.DtCompetencia, ind.DtAtualizacao)
	}
	log.Println("Carga de dados no Engine C++ concluída.")
}

func searchHandler(w http.ResponseWriter, r *http.Request) {
	uf := r.URL.Query().Get("estado")
	if uf == "" {
		http.Error(w, "Parâmetro 'estado' é obrigatório", http.StatusBadRequest)
		return
	}

	// Envia comando de Query ao C++
	fmt.Fprintf(engineStdin, "Q %s\n", strings.ToUpper(uf))

	// Lê a resposta do C++
	if engineStdout.Scan() {
		resp := engineStdout.Text()
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(resp))
	} else {
		http.Error(w, "Erro ao ler resposta do motor de busca", http.StatusInternalServerError)
	}
}

func main() {
	initEngine()
	loadFromDB()

	http.HandleFunc("/api/search", searchHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("API Nexus-SUS rodando na porta %s...\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

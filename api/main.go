package main

import (
	"bufio"
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"

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
	engineStdin      io.WriteCloser
	engineStdout     *bufio.Scanner
	engineCmd        *exec.Cmd
	engineMu         sync.Mutex
	isEngineReady    bool
	ufRegex          = regexp.MustCompile(`^[A-Z]{2}$`)
	rateLimitChannel = make(chan struct{}, 5)
)

func init() {
	go func() {
		ticker := time.NewTicker(200 * time.Millisecond)
		for range ticker.C {
			select {
			case rateLimitChannel <- struct{}{}:
			default:
			}
		}
	}()
}

// Supervisor de Processo: Garante que o motor C++ esteja rodando
func startEngineSupervisor() {
	for {
		log.Println("Iniciando motor C++...")
		initEngine()
		loadFromDB()
		isEngineReady = true

		err := engineCmd.Wait()
		isEngineReady = false
		log.Printf("Motor C++ encerrou com erro: %v. Reiniciando em 5s...", err)
		time.Sleep(5 * time.Second)
	}
}

func initEngine() {
	engineMu.Lock()
	defer engineMu.Unlock()

	engineCmd = exec.Command("./nexus-sus-engine/compiler")
	
	var err error
	engineStdin, err = engineCmd.StdinPipe()
	if err != nil {
		log.Printf("Erro ao abrir stdin: %v", err)
		return
	}

	stdout, err := engineCmd.StdoutPipe()
	if err != nil {
		log.Printf("Erro ao abrir stdout: %v", err)
		return
	}
	engineStdout = bufio.NewScanner(stdout)

	if err := engineCmd.Start(); err != nil {
		log.Printf("Erro ao iniciar motor: %v", err)
		return
	}
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

		safeUF := strings.ToUpper(strings.TrimSpace(ind.Estado))
		if !ufRegex.MatchString(safeUF) {
			continue 
		}
		safeRegiao := strings.ReplaceAll(strings.TrimSpace(ind.Regiao), " ", "_")

		engineMu.Lock()
		if engineStdin != nil {
			fmt.Fprintf(engineStdin, "L %s %s %.2f %.2f %.2f %s %s\n",
				safeUF, safeRegiao, ind.VlUF, ind.VlRegiao, ind.VlBrasil, ind.DtCompetencia, ind.DtAtualizacao)
		}
		engineMu.Unlock()
	}
	log.Println("Carga de dados no Engine C++ concluída.")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if isEngineReady {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status": "up", "engine": "ready"}`))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"status": "down", "engine": "initializing_or_failed"}`))
	}
}

func searchHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	if !isEngineReady {
		http.Error(w, `{"error": "Motor de busca temporariamente indisponível"}`, http.StatusServiceUnavailable)
		return
	}

	select {
	case <-rateLimitChannel:
	default:
		http.Error(w, `{"error": "Rate limit exceeded"}`, http.StatusTooManyRequests)
		return
	}

	uf := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("estado")))
	if !ufRegex.MatchString(uf) {
		http.Error(w, `{"error": "Estado inválido"}`, http.StatusBadRequest)
		return
	}

	engineMu.Lock()
	defer engineMu.Unlock()

	fmt.Fprintf(engineStdin, "Q %s\n", uf)

	if engineStdout.Scan() {
		resp := engineStdout.Text()
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(resp))
	} else {
		http.Error(w, `{"error": "Falha na comunicação com o motor"}`, http.StatusInternalServerError)
	}
}

func main() {
	go startEngineSupervisor()

	http.HandleFunc("/api/search", searchHandler)
	http.HandleFunc("/api/health", healthHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("API Nexus-SUS rodando na porta %s...\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}


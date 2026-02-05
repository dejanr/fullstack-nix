package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/awslabs/aws-lambda-go-api-proxy/httpadapter"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Hello, World!"})
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") != "" {
		lambda.Start(httpadapter.NewV2(mux).ProxyWithContext)
	} else {
		port := os.Getenv("PORT")
		if port == "" {
			port = "3001"
		}
		address := ":" + port
		log.Printf("Server listening on %s", address)
		if err := http.ListenAndServe(address, mux); err != nil {
			log.Fatal(err)
		}
	}
}

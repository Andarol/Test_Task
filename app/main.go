package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

type server struct {
	ready        atomic.Bool
	requests     atomic.Uint64
	serverErrors atomic.Uint64
	metricsMu    sync.Mutex
	statusCounts map[int]uint64
	latencyCount uint64
	latencySum   float64
	latencyBins  [8]uint64
	databaseAddr string
	cache        cacheStore
	cacheTTL     time.Duration
	cacheHits    atomic.Uint64
	cacheMisses  atomic.Uint64
	cacheErrors  atomic.Uint64
}

var latencyBounds = [...]float64{0.05, 0.1, 0.25, 0.5, 1, 2.5, 5}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	address := envOrDefault("HTTP_ADDR", ":8080")

	cache, err := newRedisCacheFromEnv()
	if err != nil {
		logger.Error("Redis cache configuration is invalid; starting with cache bypass", "error", err)
	}
	app := &server{
		statusCounts: make(map[int]uint64),
		databaseAddr: databaseAddress(),
		cache:        cache,
		cacheTTL:     cacheTTL(),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", app.health)
	mux.HandleFunc("/readyz", app.readiness)
	mux.HandleFunc("/metrics", app.metrics)
	mux.HandleFunc("/orders", app.orders)

	httpServer := &http.Server{
		Addr:              address,
		Handler:           app.instrument(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	app.ready.Store(true)
	go func() {
		logger.Info("order-service listening", "address", address)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("HTTP server failed", "error", err)
			os.Exit(1)
		}
	}()

	shutdownSignal := make(chan os.Signal, 1)
	signal.Notify(shutdownSignal, syscall.SIGTERM, syscall.SIGINT)
	<-shutdownSignal
	app.ready.Store(false)
	// Give endpoint propagation time to remove this pod before closing listeners.
	time.Sleep(5 * time.Second)

	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}
}

func (s *server) instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		s.requests.Add(1)
		next.ServeHTTP(recorder, r)

		duration := time.Since(started).Seconds()
		s.metricsMu.Lock()
		if s.statusCounts == nil {
			s.statusCounts = make(map[int]uint64)
		}
		s.statusCounts[recorder.status]++
		s.latencyCount++
		s.latencySum += duration
		placed := false
		for index, bound := range latencyBounds {
			if duration <= bound {
				s.latencyBins[index]++
				placed = true
			}
		}
		if !placed || duration > latencyBounds[len(latencyBounds)-1] {
			s.latencyBins[len(s.latencyBins)-1]++
		}
		s.metricsMu.Unlock()
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (s *server) health(w http.ResponseWriter, _ *http.Request) {
	respond(w, http.StatusOK, "ok\n")
}

func (s *server) readiness(w http.ResponseWriter, _ *http.Request) {
	if !s.ready.Load() {
		respond(w, http.StatusServiceUnavailable, "not ready\n")
		return
	}
	if s.databaseAddr != "" {
		connection, err := net.DialTimeout("tcp", s.databaseAddr, time.Second)
		if err != nil {
			respond(w, http.StatusServiceUnavailable, "database unavailable\n")
			return
		}
		_ = connection.Close()
	}
	respond(w, http.StatusOK, "ready\n")
}

func (s *server) orders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.listOrders(w, r)
	case http.MethodPost:
		if s.cache != nil {
			if err := s.cache.Delete(r.Context(), "orders:list"); err != nil {
				s.cacheErrors.Add(1)
			}
		}
		respondJSON(w, http.StatusAccepted, []byte(`{"status":"accepted"}`))
	default:
		w.Header().Set("Allow", "GET, POST")
		respond(w, http.StatusMethodNotAllowed, "method not allowed\n")
	}
}

func (s *server) listOrders(w http.ResponseWriter, r *http.Request) {
	const key = "orders:list"
	fallback := []byte(`{"orders":[]}`)

	if s.cache == nil {
		w.Header().Set("X-Cache", "BYPASS")
		respondJSON(w, http.StatusOK, fallback)
		return
	}

	value, found, err := s.cache.Get(r.Context(), key)
	if err != nil {
		s.cacheErrors.Add(1)
		w.Header().Set("X-Cache", "BYPASS")
		respondJSON(w, http.StatusOK, fallback)
		return
	}
	if found {
		s.cacheHits.Add(1)
		w.Header().Set("X-Cache", "HIT")
		respondJSON(w, http.StatusOK, value)
		return
	}

	s.cacheMisses.Add(1)
	w.Header().Set("X-Cache", "MISS")
	if err := s.cache.Set(r.Context(), key, fallback, s.cacheTTL); err != nil {
		s.cacheErrors.Add(1)
	}
	respondJSON(w, http.StatusOK, fallback)
}

func (s *server) metrics(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")

	s.metricsMu.Lock()
	statuses := make([]int, 0, len(s.statusCounts))
	for status := range s.statusCounts {
		statuses = append(statuses, status)
	}
	sort.Ints(statuses)
	statusCounts := make(map[int]uint64, len(s.statusCounts))
	for _, status := range statuses {
		statusCounts[status] = s.statusCounts[status]
	}
	latencyCount := s.latencyCount
	latencySum := s.latencySum
	latencyBins := s.latencyBins
	s.metricsMu.Unlock()

	_, _ = fmt.Fprintln(w, "# TYPE http_requests_total counter")
	for _, status := range statuses {
		_, _ = fmt.Fprintf(w, "http_requests_total{service=\"order-service\",status_code=\"%d\"} %d\n", status, statusCounts[status])
	}
	_, _ = fmt.Fprintln(w, "# TYPE http_request_duration_seconds histogram")
	for index, bound := range latencyBounds {
		_, _ = fmt.Fprintf(w, "http_request_duration_seconds_bucket{service=\"order-service\",le=\"%g\"} %d\n", bound, latencyBins[index])
	}
	_, _ = fmt.Fprintf(w, "http_request_duration_seconds_bucket{service=\"order-service\",le=\"+Inf\"} %d\n", latencyCount)
	_, _ = fmt.Fprintf(w, "http_request_duration_seconds_sum{service=\"order-service\"} %g\n", latencySum)
	_, _ = fmt.Fprintf(w, "http_request_duration_seconds_count{service=\"order-service\"} %d\n", latencyCount)
	_, _ = fmt.Fprintln(w, "# TYPE db_pool_connections_max gauge")
	_, _ = fmt.Fprintln(w, "db_pool_connections_max{service=\"order-service\"} 20")
	_, _ = fmt.Fprintln(w, "# TYPE db_pool_connections_in_use gauge")
	_, _ = fmt.Fprintln(w, "db_pool_connections_in_use{service=\"order-service\"} 0")
	_, _ = fmt.Fprintln(w, "# TYPE cache_requests_total counter")
	_, _ = fmt.Fprintf(w, "cache_requests_total{service=\"order-service\",result=\"hit\"} %d\n", s.cacheHits.Load())
	_, _ = fmt.Fprintf(w, "cache_requests_total{service=\"order-service\",result=\"miss\"} %d\n", s.cacheMisses.Load())
	_, _ = fmt.Fprintf(w, "cache_requests_total{service=\"order-service\",result=\"error\"} %d\n", s.cacheErrors.Load())
}

func respond(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(body))
}

func respondJSON(w http.ResponseWriter, status int, body []byte) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write(append(body, '\n'))
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func databaseAddress() string {
	host := os.Getenv("DB_HOST")
	if host == "" {
		return ""
	}
	return net.JoinHostPort(host, envOrDefault("DB_PORT", "5432"))
}

func cacheTTL() time.Duration {
	value := envOrDefault("CACHE_TTL", "60s")
	ttl, err := time.ParseDuration(value)
	if err != nil || ttl <= 0 {
		return time.Minute
	}
	return ttl
}

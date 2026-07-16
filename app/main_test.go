package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHealth(t *testing.T) {
	app := &server{}
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	recorder := httptest.NewRecorder()
	app.health(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}

func TestReadiness(t *testing.T) {
	app := &server{}
	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)

	notReady := httptest.NewRecorder()
	app.readiness(notReady, request)
	if notReady.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 before startup, got %d", notReady.Code)
	}

	app.ready.Store(true)
	ready := httptest.NewRecorder()
	app.readiness(ready, request)
	if ready.Code != http.StatusOK {
		t.Fatalf("expected 200 after startup, got %d", ready.Code)
	}
}

func TestOrdersRejectsUnsupportedMethod(t *testing.T) {
	app := &server{}
	request := httptest.NewRequest(http.MethodDelete, "/orders", nil)
	recorder := httptest.NewRecorder()
	app.orders(recorder, request)
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", recorder.Code)
	}
}

type memoryCache struct {
	value    []byte
	found    bool
	setCalls int
	deletes  int
}

func (c *memoryCache) Get(context.Context, string) ([]byte, bool, error) {
	return c.value, c.found, nil
}

func (c *memoryCache) Set(_ context.Context, _ string, value []byte, _ time.Duration) error {
	c.value = value
	c.found = true
	c.setCalls++
	return nil
}

func (c *memoryCache) Delete(context.Context, string) error {
	c.found = false
	c.deletes++
	return nil
}

func TestOrdersCacheAside(t *testing.T) {
	cache := &memoryCache{}
	app := &server{cache: cache, cacheTTL: time.Minute}

	miss := httptest.NewRecorder()
	app.orders(miss, httptest.NewRequest(http.MethodGet, "/orders", nil))
	if miss.Code != http.StatusOK || miss.Header().Get("X-Cache") != "MISS" || cache.setCalls != 1 {
		t.Fatalf("expected cache miss and population, got status=%d cache=%q sets=%d", miss.Code, miss.Header().Get("X-Cache"), cache.setCalls)
	}

	hit := httptest.NewRecorder()
	app.orders(hit, httptest.NewRequest(http.MethodGet, "/orders", nil))
	if hit.Header().Get("X-Cache") != "HIT" {
		t.Fatalf("expected cache hit, got %q", hit.Header().Get("X-Cache"))
	}

	created := httptest.NewRecorder()
	app.orders(created, httptest.NewRequest(http.MethodPost, "/orders", nil))
	if created.Code != http.StatusAccepted || cache.deletes != 1 {
		t.Fatalf("expected accepted response and invalidation, got status=%d deletes=%d", created.Code, cache.deletes)
	}
}

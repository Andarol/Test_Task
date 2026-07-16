package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
)

type cacheStore interface {
	Get(context.Context, string) ([]byte, bool, error)
	Set(context.Context, string, []byte, time.Duration) error
	Delete(context.Context, string) error
}

type redisCache struct {
	address   string
	password  string
	tlsConfig *tls.Config
}

func newRedisCacheFromEnv() (cacheStore, error) {
	host := os.Getenv("REDIS_HOST")
	if host == "" {
		return nil, nil
	}
	caPEM := os.Getenv("REDIS_TLS_CA")
	if caPEM == "" {
		return nil, errors.New("REDIS_TLS_CA is required when REDIS_HOST is set")
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM([]byte(caPEM)) {
		return nil, errors.New("REDIS_TLS_CA contains no valid certificate")
	}
	return &redisCache{
		address:  net.JoinHostPort(host, envOrDefault("REDIS_PORT", "6378")),
		password: os.Getenv("REDIS_AUTH"),
		tlsConfig: &tls.Config{
			MinVersion: tls.VersionTLS12,
			RootCAs:    roots,
		},
	}, nil
}

func (c *redisCache) Get(ctx context.Context, key string) ([]byte, bool, error) {
	response, err := c.command(ctx, "GET", key)
	if err != nil {
		return nil, false, err
	}
	return response.value, !response.nil, nil
}

func (c *redisCache) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	seconds := max(int64(ttl/time.Second), 1)
	_, err := c.command(ctx, "SET", key, string(value), "EX", strconv.FormatInt(seconds, 10))
	return err
}

func (c *redisCache) Delete(ctx context.Context, key string) error {
	_, err := c.command(ctx, "DEL", key)
	return err
}

type redisResponse struct {
	value []byte
	nil   bool
}

func (c *redisCache) command(ctx context.Context, args ...string) (redisResponse, error) {
	dialer := &tls.Dialer{
		NetDialer: &net.Dialer{Timeout: 1500 * time.Millisecond},
		Config:    c.tlsConfig.Clone(),
	}
	connection, err := dialer.DialContext(ctx, "tcp", c.address)
	if err != nil {
		return redisResponse{}, err
	}
	defer connection.Close()

	deadline := time.Now().Add(2 * time.Second)
	if contextDeadline, ok := ctx.Deadline(); ok && contextDeadline.Before(deadline) {
		deadline = contextDeadline
	}
	if err := connection.SetDeadline(deadline); err != nil {
		return redisResponse{}, err
	}
	reader := bufio.NewReader(connection)

	if c.password != "" {
		if err := writeRedisCommand(connection, "AUTH", c.password); err != nil {
			return redisResponse{}, err
		}
		if _, err := readRedisResponse(reader); err != nil {
			return redisResponse{}, fmt.Errorf("Redis AUTH failed: %w", err)
		}
	}
	if err := writeRedisCommand(connection, args...); err != nil {
		return redisResponse{}, err
	}
	return readRedisResponse(reader)
}

func writeRedisCommand(writer io.Writer, args ...string) error {
	var command bytes.Buffer
	_, _ = fmt.Fprintf(&command, "*%d\r\n", len(args))
	for _, arg := range args {
		_, _ = fmt.Fprintf(&command, "$%d\r\n", len(arg))
		command.WriteString(arg)
		command.WriteString("\r\n")
	}
	_, err := writer.Write(command.Bytes())
	return err
}

func readRedisResponse(reader *bufio.Reader) (redisResponse, error) {
	prefix, err := reader.ReadByte()
	if err != nil {
		return redisResponse{}, err
	}
	line, err := reader.ReadString('\n')
	if err != nil {
		return redisResponse{}, err
	}
	line = strings.TrimSuffix(strings.TrimSuffix(line, "\n"), "\r")

	switch prefix {
	case '+', ':':
		return redisResponse{value: []byte(line)}, nil
	case '-':
		return redisResponse{}, fmt.Errorf("Redis error: %s", line)
	case '$':
		length, err := strconv.Atoi(line)
		if err != nil {
			return redisResponse{}, fmt.Errorf("invalid Redis bulk length %q: %w", line, err)
		}
		if length == -1 {
			return redisResponse{nil: true}, nil
		}
		if length < 0 {
			return redisResponse{}, fmt.Errorf("invalid Redis bulk length %d", length)
		}
		value := make([]byte, length+2)
		if _, err := io.ReadFull(reader, value); err != nil {
			return redisResponse{}, err
		}
		if !bytes.Equal(value[length:], []byte("\r\n")) {
			return redisResponse{}, errors.New("invalid Redis bulk terminator")
		}
		return redisResponse{value: value[:length]}, nil
	default:
		return redisResponse{}, fmt.Errorf("unsupported Redis response prefix %q", prefix)
	}
}

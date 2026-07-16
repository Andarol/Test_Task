# syntax=docker/dockerfile:1.7
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY app ./app
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/order-service ./app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/order-service /order-service
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/order-service"]

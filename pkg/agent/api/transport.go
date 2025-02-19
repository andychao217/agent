// Copyright (c) Abstract Machines
// SPDX-License-Identifier: Apache-2.0

package api

import (
	"context"
	"encoding/json"

	"github.com/andychao217/agent/pkg/agent"
	"github.com/andychao217/magistrala"
	"github.com/go-zoo/bone"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"net/http"

	kithttp "github.com/go-kit/kit/transport/http"
)

// MakeHandler returns a HTTP handler for API endpoints.
func MakeHandler(svc agent.Service) http.Handler {
	r := bone.New()

	r.Post("/pub", kithttp.NewServer(
		pubEndpoint(svc),
		decodePublishRequest,
		encodeResponse,
	))

	r.Post("/exec", kithttp.NewServer(
		execEndpoint(svc),
		decodeExecRequest,
		encodeResponse,
	))

	r.Post("/config", kithttp.NewServer(
		addConfigEndpoint(svc),
		decodeAddConfigRequest,
		encodeResponse,
	))

	r.Get("/config", kithttp.NewServer(
		viewConfigEndpoint(svc),
		decodeRequest,
		encodeResponse,
	))

	r.Get("/services", kithttp.NewServer(
		viewServicesEndpoint(svc),
		decodeRequest,
		encodeResponse,
	))

	r.Handle("/metrics", promhttp.Handler())
	r.GetFunc("/health", magistrala.Health("agent", ""))

	return r
}

func decodeRequest(_ context.Context, r *http.Request) (interface{}, error) {
	return nil, nil
}

func decodePublishRequest(_ context.Context, r *http.Request) (interface{}, error) {
	req := pubReq{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return nil, err
	}

	return req, nil
}

func decodeExecRequest(_ context.Context, r *http.Request) (interface{}, error) {
	req := execReq{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return nil, err
	}

	return req, nil
}

func decodeAddConfigRequest(_ context.Context, r *http.Request) (interface{}, error) {
	req := addConfigReq{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return nil, err
	}

	return req, nil
}

func encodeResponse(_ context.Context, w http.ResponseWriter, response interface{}) error {
	return json.NewEncoder(w).Encode(response)
}

# Copyright (c) Abstract Machines
# SPDX-License-Identifier: Apache-2.0

BUILD_DIR ?= build
SERVICES = agent
DOCKERS = $(addprefix docker_,$(SERVICES))
DOCKERS_DEV = $(addprefix docker_dev_,$(SERVICES))
CGO_ENABLED ?= 0
GOARCH ?= amd64
VERSION ?= $(shell git describe --abbrev=0 --tags)
COMMIT ?= $(shell git rev-parse HEAD)
TIME ?= $(shell date +%F_%T)

ifneq ($(MG_BROKER_TYPE),)
    MG_BROKER_TYPE := $(MG_BROKER_TYPE)
else
    MG_BROKER_TYPE=nats
endif

define compile_service
	CGO_ENABLED=$(CGO_ENABLED) GOOS=$(GOOS) GOARCH=$(GOARCH) GOARM=$(GOARM) \
	go build -mod=vendor -tags $(MG_BROKER_TYPE) -ldflags "-s -w \
	-X 'github.com/andychao217/agent.BuildTime=$(TIME)' \
	-X 'github.com/andychao217/agent.Version=$(VERSION)' \
	-X 'github.com/andychao217/agent.Commit=$(COMMIT)'" \
	-o ${BUILD_DIR}/magistrala-$(1) cmd/main.go
endef

define make_docker
	$(eval svc=$(subst docker_,,$(1)))

	docker build \
		--no-cache \
		--build-arg SVC=$(svc) \
		--build-arg GOARCH=$(GOARCH) \
		--build-arg GOARM=$(GOARM) \
		--build-arg VERSION=$(VERSION) \
		--build-arg COMMIT=$(COMMIT) \
		--build-arg TIME=$(TIME) \
		--tag=magistrala/$(svc) \
		-f docker/Dockerfile .
endef

define make_docker_dev
	$(eval svc=$(subst docker_dev_,,$(1)))

	docker build \
		--no-cache \
		--build-arg SVC=$(svc) \
		--tag=magistrala/$(svc) \
		-f docker/Dockerfile.dev ./build
endef

all: $(SERVICES) 

.PHONY: all $(SERVICES) dockers dockers_dev latest release

clean:
	rm -rf ${BUILD_DIR}
	

install:
	cp ${BUILD_DIR}/* $(GOBIN)

test:
	go test -v -race -count 1 -tags test $(shell go list ./... | grep -v 'vendor\|cmd')


$(SERVICES):
	$(call compile_service,$(@))

$(DOCKERS):
	$(call make_docker,$(@),$(GOARCH))

$(DOCKERS_DEV):
	$(call make_docker_dev,$(@))

dockers: $(DOCKERS)

dockers_dev: $(DOCKERS_DEV)


define docker_push
	for svc in $(SERVICES); do \
		docker push magistrala/$$svc:$(1); \
	done
endef

changelog:
	git log $(shell git describe --tags --abbrev=0)..HEAD --pretty=format:"- %s"

latest: dockers
	$(call docker_push,latest)

release:
	$(eval version = $(shell git describe --abbrev=0 --tags))
	git checkout $(version)
	$(MAKE) dockers
	for svc in $(SERVICES); do \
		docker tag magistrala/$$svc magistrala/$$svc:$(version); \
	done
	$(call docker_push,$(version))

rundev:
	cd scripts && ./run.sh

run:
	docker-compose -f docker/docker-compose.yml up

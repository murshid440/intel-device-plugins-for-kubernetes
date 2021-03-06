GO := go
GOCYCLO := gocyclo

pkgs  = $(shell $(GO) list ./... | grep -v vendor)
cmds = $(shell ls cmd)

all: build

format:
	@$(GO) fmt $(pkgs)

vet:
	@$(GO) vet -v -shadow $(pkgs)

cyclomatic-check:
	@report=`$(GOCYCLO) -over 15 cmd internal`; if [ -n "$$report" ]; then echo "Complexity is over 15 in"; echo $$report; exit 1; fi

test:
ifndef WHAT
	@$(GO) test -race -coverprofile=coverage.txt -covermode=atomic $(pkgs)
else
	@cd $(WHAT) && \
            $(GO) test -v -cover -coverprofile cover.out -args -logtostderr -v 2 || rc=1; \
            $(GO) tool cover -html=cover.out -o coverage.html; \
            rm cover.out; \
            echo "Coverage report: file://$$(realpath coverage.html)"; \
            exit $$rc
endif

lint:
	@rc=0 ; for f in $$(find -name \*.go | grep -v \.\/vendor) ; do golint -set_exit_status $$f || rc=1 ; done ; exit $$rc

$(cmds):
	cd cmd/$@; go build

build: $(cmds)

DOCKER_ARGS?=--build-arg HTTP_PROXY --build-arg HTTPS_PROXY --build-arg NO_PROXY --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy --pull
TAG?=$(shell git rev-parse HEAD)

images = $(shell ls build/docker/*.Dockerfile | sed 's/.*\/\(.\+\)\.Dockerfile/\1/')

$(images):
	docker build -f build/docker/$@.Dockerfile $(DOCKER_ARGS) -t $@:$(TAG) .
	docker tag $@:$(TAG) $@:devel

images: $(images)

.PHONY: all format vet cyclomatic-check test lint build images $(cmds) $(images)

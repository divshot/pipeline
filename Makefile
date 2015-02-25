.PHONY: agent build

all: agent build

agent: agent/Dockerfile agent/hooks/* agent/bootstrap.sh
	docker build -t divshot/pipeline-agent --rm=true ./agent
build: build/Dockerfile build/scripts/*
	docker build -t divshot/pipeline-build --rm=true ./build
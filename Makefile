all: agent build

agent: agent/Dockerfile
	docker build -t divshot/pipeline-agent --rm=true ./agent
build: build/Dockerfile
	docker build -t divshot/pipeline-build --rm=true ./build
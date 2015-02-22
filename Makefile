all: agent build deploy

agent: agent/Dockerfile agent/hooks/* agent/bootstrap.sh
	docker build -t divshot/pipeline-agent --rm=true ./agent
build: build/Dockerfile build/scripts/*
	docker build -t divshot/pipeline-build --rm=true ./build
deploy: deploy/Dockerfile deploy/deploy.sh
	docker build -t divshot/pipeline-deploy --rm=true ./deploy
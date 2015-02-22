all: agent base node ruby

agent: agent/Dockerfile
	docker build -t divshot/pipeline-agent --rm=true ./agent
base: base/Dockerfile
	docker build -t divshot/pipeline-base --rm=true ./base
node: node/Dockerfile
	docker build -t divshot/pipeline-node --rm=true ./node
ruby: ruby/Dockerfile
	docker build -t divshot/pipeline-ruby --rm=true ./ruby


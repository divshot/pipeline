# Divshot Pipeline

These public Docker images power the Divshot Pipeline build servers in conjunction
with [Buildkite](https://buildkite.com). The `divshot/pipeline-agent` image runs
to coordinate with the Buildkite service and spawns `divshot/pipeline-build`
containers to perform the actual build process. Then a `divshot/pipeline-deploy`
container is used to deploy the result to Divshot.

## Building

To build the images locally, just run:

    make all

## Running

To run the agent, you'll first need to create a container with a shared data
volume so that both the agent and the build container can access it. After you
build the images using `make all`, you should start a container named `divshot-pipeline-data`
like so:

    docker run --name divshot-pipeline-data -v /builds -v /cache divshot/pipeline-agent echo "Build Data"

Next, we'll need to start the Buildkite agent. We can do this like so:

    docker run -e BUILDKITE_AGENT_TOKEN=xxx --volumes-from divshot-pipeline-data -v /var/run/docker.sock divshot/pipeline-agent

Where the `xxx` of `BUILDKITE_AGENT_TOKEN` is the actual agent token. Once the
agent is running, it will automatically register itself with Buildkite and be
available to start processing jobs.
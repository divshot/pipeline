# Pipeline Build Agent

This is the build agent that connects to [Buildkite](https://buildkite.com/)
and coordinates builds.

## Usage

You must supply the `BUILDKITE_AGENT_TOKEN` environment variable when running
this container. Additionally, you will need to pass through the Docker socket
to allow the agent to spin up additional containers for the actual builds.

Finally, the `/builds` and `/hooks` directory are volumes that should be attached
to larger storage of some kind.

    docker run -e BUILDKITE_AGENT_TOKEN=xxx \
               -v /var/run/docker.sock:/var/run/docker.sock \
               divshot/pipeline-agent
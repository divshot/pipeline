#!/bin/bash

#
#  _           _ _     _ _    _ _          _                 _       _
# | |         (_) |   | | |  (_) |        | |               | |     | |
# | |__  _   _ _| | __| | | ___| |_ ___   | |__   ___   ___ | |_ ___| |_ _ __ __ _ _ __
# | '_ \| | | | | |/ _` | |/ / | __/ _ \  | '_ \ / _ \ / _ \| __/ __| __| '__/ _` | '_ \
# | |_) | |_| | | | (_| |   <| | ||  __/  | |_) | (_) | (_) | |_\__ \ |_| | | (_| | |_) |
# |_.__/ \__,_|_|_|\__,_|_|\_\_|\__\___|  |_.__/ \___/ \___/ \__|___/\__|_|  \__,_| .__/
#                                                                                 | |
#                                                                                 |_|
# https://github.com/buildkite/agent/blob/master/templates/bootstrap.sh

# Causes this script to exit if a variable isn't present
set -u

##############################################################
#
# BOOTSTRAP FUNCTIONS
# These functions are used throughout the bootstrap.sh file
#
##############################################################

BUILDKITE_PROMPT="\033[90m$\033[0m"

# Shows the command being run, and runs it
function buildkite-prompt-and-run {
  echo -e "$BUILDKITE_PROMPT $1"
  eval $1
}

# Shows the command about to be run, and exits if it fails
function buildkite-run {
  echo -e "$BUILDKITE_PROMPT $1"
  eval $1
  EVAL_EXIT_STATUS=$?

  if [[ $EVAL_EXIT_STATUS -ne 0 ]]; then
    exit $EVAL_EXIT_STATUS
  fi
}

function buildkite-debug {
  if [[ "$BUILDKITE_AGENT_DEBUG" == "true" ]]; then
    echo -e "$1"
  fi
}

# Runs the command, but only output what it's doing if we're in DEBUG mode
function buildkite-run-debug {
  buildkite-debug "$BUILDKITE_PROMPT $1"
  eval $1
}

# Show an error and exit
function buildkite-error {
  echo -e "\033[31mERROR:\033[0m $1"
  exit 1
}

# Run a hook script
function buildkite-hook {
  HOOK_LABEL="$1"
  HOOK_SCRIPT_PATH="$2"

  if [[ -e "$HOOK_SCRIPT_PATH" ]]; then
    # Print to the screen we're going to run the hook
    echo "--- Running $HOOK_LABEL hook"
    echo -e "$BUILDKITE_PROMPT . \"$HOOK_SCRIPT_PATH\""

    # Run the hook
    . "$HOOK_SCRIPT_PATH"
    HOOK_EXIT_STATUS=$?

    # Exit from the bootstrap.sh script if the hook exits with a non-0 exit
    # status
    if [[ $HOOK_EXIT_STATUS -ne 0 ]]; then
      echo "Hook returned an exit status of $HOOK_EXIT_STATUS, exiting..."
      exit $HOOK_EXIT_STATUS
    fi
  elif [[ "$BUILDKITE_AGENT_DEBUG" == "true" ]]; then
    # When in debug mode, show that we've skipped a hook
    echo "--- Running $HOOK_LABEL hook"
    echo "Skipping, no hook script found at: $HOOK_SCRIPT_PATH"
  fi
}

function buildkite-global-hook {
  buildkite-hook "global $1" "$BUILDKITE_HOOKS_PATH/$1"
}

function buildkite-local-hook {
  buildkite-hook "local $1" ".buildkite/hooks/$1"
}

##############################################################
#
# PATH DEFAULTS
# Come up with the paths used throughout the bootstrap.sh file
#
##############################################################

# Add the $BUILDKITE_BIN_PATH to the $PATH
export PATH="$BUILDKITE_BIN_PATH:$PATH"

# Come up with the place that the repository will be checked out to
SANITIZED_AGENT_NAME=$(echo $BUILDKITE_AGENT_NAME | tr -d '"')
PROJECT_FOLDER_NAME="$SANITIZED_AGENT_NAME/$BUILDKITE_PROJECT_SLUG"
BUILDKITE_BUILD_CHECKOUT_PATH="$BUILDKITE_BUILD_PATH/$PROJECT_FOLDER_NAME"

export BUILDKITE_BUILD_FOLDER_NAME=$PROJECT_FOLDER_NAME

if [[ "$BUILDKITE_AGENT_DEBUG" == "true" ]]; then
  echo "--- Build environment variables"

  buildkite-run "env | grep BUILDKITE | sort"
fi

##############################################################
#
# REPOSITORY HANDLING
# Creates the build folder and makes sure we're running the
# build at the right commit.
#
##############################################################

# Run the `pre-checkout` hook
buildkite-global-hook "pre-checkout"

# Remove the checkout folder if BUILDKITE_CLEAN_CHECKOUT is present
if [[ ! -z "${BUILDKITE_CLEAN_CHECKOUT:-}" ]] && [[ "$BUILDKITE_CLEAN_CHECKOUT" == "true" ]]; then
  echo "--- Cleaning project checkout"

  buildkite-run "rm -rf \"$BUILDKITE_BUILD_CHECKOUT_PATH\""
fi

echo "--- Preparing build folder"

buildkite-run "mkdir -p \"$BUILDKITE_BUILD_CHECKOUT_PATH\""
buildkite-run "cd \"$BUILDKITE_BUILD_CHECKOUT_PATH\""

# If the user has specificed their own checkout hook
if [[ -e "$BUILDKITE_HOOKS_PATH/checkout" ]]; then
  buildkite-global-hook "checkout"
else
  # If enabled, automatically run an ssh-keyscan on the git ssh host, to prevent
  # a yes/no promp from appearing when cloning/fetching
  if [[ ! -z "${BUILDKITE_AUTO_SSH_FINGERPRINT_VERIFICATION:-}" ]] && [[ "$BUILDKITE_AUTO_SSH_FINGERPRINT_VERIFICATION" == "true" ]]; then
    # Only bother running the keyscan if the SSH host has been provided by
    # Buildkite. It won't be present if the host isn't using the SSH protocol
    if [[ ! -z "${BUILDKITE_REPO_SSH_HOST:-}" ]]; then
      : ${BUILDKITE_SSH_DIRECTORY:="$HOME/.ssh"}
      : ${BUILDKITE_SSH_KNOWN_HOST_PATH:="$BUILDKITE_SSH_DIRECTORY/known_hosts"}

      # Ensure the known_hosts file exists
      mkdir -p $BUILDKITE_SSH_DIRECTORY
      touch $BUILDKITE_SSH_KNOWN_HOST_PATH

      # Only add the output from ssh-keyscan if it doesn't already exist in the
      # known_hosts file
      if ! ssh-keygen -H -F "$BUILDKITE_REPO_SSH_HOST" | grep --quiet "$BUILDKITE_REPO_SSH_HOST"; then
        buildkite-run "ssh-keyscan \"$BUILDKITE_REPO_SSH_HOST\" >> \"$BUILDKITE_SSH_KNOWN_HOST_PATH\""
      fi
    fi
  fi

  # Disable any interactive Git/SSH prompting
  export GIT_TERMINAL_PROMPT=0

  # Do we need to do a git checkout?
  if [[ ! -d ".git" ]]; then
    buildkite-run "git clone \"$BUILDKITE_REPO\" . -qv"
  fi

  buildkite-run "git clean -fdq"
  buildkite-run "git submodule foreach --recursive git clean -fdq"

  buildkite-run "git fetch -q"

  # Allow checkouts of forked pull requests on GitHub only. See:
  # https://help.github.com/articles/checking-out-pull-requests-locally/#modifying-an-inactive-pull-request-locally
  if [[ "$BUILDKITE_PULL_REQUEST" != "false" ]] && [[ "$BUILDKITE_PROJECT_PROVIDER" == *"github"* ]]; then
    buildkite-run "git fetch origin \"+refs/pull/$BUILDKITE_PULL_REQUEST/head:\""
  elif [[ "$BUILDKITE_TAG" == "" ]]; then
    # Default empty branch names
    : ${BUILDKITE_BRANCH:=master}

    buildkite-run "git reset --hard origin/$BUILDKITE_BRANCH"
  fi

  buildkite-run "git checkout -qf \"$BUILDKITE_COMMIT\""

  # `submodule sync` will ensure the .git/config matches the .gitmodules file
  buildkite-run "git submodule sync"
  buildkite-run "git submodule update --init --recursive"
  buildkite-run "git submodule foreach --recursive git reset --hard"

  # Grab author and commit information and send it back to Buildkite
  buildkite-debug "--- Saving Git information"
  buildkite-run-debug "buildkite-agent build-data set \"buildkite:git:commit\" \"\`git show \"$BUILDKITE_COMMIT\" -s --format=fuller --no-color\`\""
  buildkite-run-debug "buildkite-agent build-data set \"buildkite:git:branch\" \"\`git branch --contains \"$BUILDKITE_COMMIT\" --no-color\`\""
fi

# Run the `post-checkout` hook
buildkite-global-hook "post-checkout"

##############################################################
#
# RUN THE BUILD
# Determines how to run the build, and then runs it
#
##############################################################

# Make sure we actually have a command to run
if [[ "$BUILDKITE_COMMAND" == "" ]]; then
  buildkite-error "No command has been defined. Please go to \"Project Settings\" and configure your build step's \"Command\""
fi

# If the command is a file on the filesystem, that's the script we're going to
# run
if [[ -e "$BUILDKITE_COMMAND" ]]; then
  BUILDKITE_SCRIPT_PATH=$BUILDKITE_COMMAND
else
  # If the command isn't a file, then it's probably a command with arguments we
  # need to run.
  if [[ "$BUILDKITE_SCRIPT_EVAL" == "true" ]]; then
    BUILDKITE_SCRIPT_PATH="buildkite-script-$BUILDKITE_JOB_ID"

    echo "$BUILDKITE_COMMAND" > $BUILDKITE_SCRIPT_PATH
  else
    buildkite-error "This agent has not been allowed to evaluate scripts. Re-run this agent and remove the \`--no-script-eval\` option, or specify a script on the file system to run instead."
  fi
fi

# Make sure the script we're going to run is executable
chmod +x $BUILDKITE_SCRIPT_PATH

# Run the global `pre-command` hook
buildkite-global-hook "pre-command"

# Run the per-checkout `pre-command` hook
buildkite-local-hook "pre-command"

# If the user has specificed their own command hook
if [[ -e "$BUILDKITE_HOOKS_PATH/command" ]]; then
  buildkite-global-hook "command"

  # Capture the exit status from the build script
  export BUILDKITE_COMMAND_EXIT_STATUS=$?
else
  ## Docker
  if [[ ! -z "${BUILDKITE_DOCKER:-}" ]] && [[ "$BUILDKITE_DOCKER" != "" ]]; then
    DOCKER_CONTAINER="buildkite_"$BUILDKITE_JOB_ID"_container"
    DOCKER_IMAGE="buildkite_"$BUILDKITE_JOB_ID"_image"

    function docker-cleanup {
      echo "--- Cleaning up Docker containers"
      buildkite-run "docker rm -f -v $DOCKER_CONTAINER"

      # Enabling the following line will prevent your build server from filling up,
      # but will slow down your builds because it'll be built from scratch each time.
      #
      # docker rmi -f -v $DOCKER_IMAGE
    }

    trap docker-cleanup EXIT

    # Build the Docker image, namespaced to the job
    echo "--- Building Docker image $DOCKER_IMAGE"
    buildkite-run "docker build -t $DOCKER_IMAGE ."

    # Run the build script command in a one-off container
    echo "--- Running build script (in Docker container)"
    buildkite-prompt-and-run "docker run --name $DOCKER_CONTAINER $DOCKER_IMAGE ./$BUILDKITE_SCRIPT_PATH"

    # Capture the exit status from the build script
    export BUILDKITE_COMMAND_EXIT_STATUS=$?

  ## Fig
  elif [[ ! -z "${BUILDKITE_FIG_CONTAINER:-}" ]] && [[ "$BUILDKITE_FIG_CONTAINER" != "" ]]; then
    # Fig strips dashes and underscores, so we'll remove them to match the docker container names
    FIG_PROJ_NAME="buildkite"${BUILDKITE_JOB_ID//-}
    # The name of the docker container fig creates when it creates the adhoc run
    FIG_CONTAINER_NAME=$FIG_PROJ_NAME"_"$BUILDKITE_FIG_CONTAINER

    function fig-cleanup {
      echo "--- Cleaning up Fig Docker containers"
      buildkite-run "fig -p $FIG_PROJ_NAME kill"
      buildkite-run "fig -p $FIG_PROJ_NAME rm --force -v"

      # The adhoc run container isn't cleaned up by fig, so we have to do it ourselves
      buildkite-run "docker rm -f -v "$FIG_CONTAINER_NAME"_run_1"

      # Enabling the following line will prevent your build server from filling up,
      # but will slow down your builds because it'll be built from scratch each time.
      #
      # docker rmi -f -v $FIG_CONTAINER_NAME
    }

    trap fig-cleanup EXIT

    # Build the Docker images using Fig, namespaced to the job
    echo "--- Building Fig Docker images"
    buildkite-run "fig -p $FIG_PROJ_NAME build"

    # Run the build script command in the service specified in BUILDKITE_FIG_CONTAINER
    echo "--- Running build script (in Fig container)"
    buildkite-prompt-and-run "fig -p $FIG_PROJ_NAME run $BUILDKITE_FIG_CONTAINER ./$BUILDKITE_SCRIPT_PATH"

    # Capture the exit status from the build script
    export BUILDKITE_COMMAND_EXIT_STATUS=$?

  ## Standard
  else
    echo "--- Running build script"
    echo -e "$BUILDKITE_PROMPT . \"$BUILDKITE_SCRIPT_PATH\""
    ."/$BUILDKITE_SCRIPT_PATH"

    # Capture the exit status from the build script
    export BUILDKITE_COMMAND_EXIT_STATUS=$?
  fi
fi

# Run the per-checkout `post-command` hook
buildkite-local-hook "post-command"

# Run the global `post-command` hook
buildkite-global-hook "post-command"

##############################################################
#
# ARTIFACTS
# Uploads and build artifacts associated with this build
#
##############################################################

if [[ "$BUILDKITE_ARTIFACT_PATHS" != "" ]]; then
  # If you want to upload artifacts to your own server, uncomment the lines below
  # and replace the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY with keys to your
  # own bucket.
  #
  # export AWS_SECRET_ACCESS_KEY=yyy
  # export AWS_ACCESS_KEY_ID=xxx
  # export AWS_S3_ACL=private
  # buildkite-run "buildkite-agent build-artifact upload \"$BUILDKITE_ARTIFACT_PATHS\" \"s3://name-of-your-s3-bucket/$BUILDKITE_JOB_ID\""

  echo "--- Uploading artifacts"
  buildkite-run "buildkite-agent build-artifact upload \"$BUILDKITE_ARTIFACT_PATHS\""
fi

# Be sure to exit this script with the same exit status that the users build
# script exited with.
exit $BUILDKITE_COMMAND_EXIT_STATUS

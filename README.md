# Divshot Pipeline Containers

Build your front-end apps and static sites with the power of Docker.

**Note:** These buildpacks are designed to be run by a build server. They can
and will mess with file permissions of volumes mounted into them.

## node

A Node.js build container with Bower, Grunt, Gulp, Broccoli, and Ember CLI already
installed. Additional dependencies will be installed with `npm install` and
`bower install`.

You must have a `build` script in your `package.json` file that performs the
necessary build, and the build must be in a subtree of your project's working
directory.

```json
{
  "scripts": {
    "build": "grunt build:dist"
  }
}
```
# Ruby on Rails Dockerfile
# This Dockerfile is used to build a Ruby on Rails application image.

# FROM <base-image>:<tag>
# Why version 3.4.4?: https://www.ruby-lang.org/ja/downloads/
# What is alpine?: https://alpinelinux.org/
FROM ruby:3.4.4-alpine

# Define variable to be used in the Dockerfile
# default value is "app"
ARG WORKDIR
# Packages required for the application to run
ARG RUNTIME_PACKAGES="nodejs tzdata postgresql-dev postgresql-client git libxml2-dev libxslt-dev yaml-dev"
# Packages required for development and building the application
ARG DEV_PACKAGES="build-base curl-dev"

# Define environment variables
# HOME: Home directory for the application
# LANG: Locale setting
# TZ: Timezone setting
ENV HOME=/${WORKDIR} \
    LANG=C.UTF-8 \
    TZ=Asia/Tokyo

# Execute the instructions specified in the Dockerfile ... RUN, COPY, CMD, ENTORYPOINT, etc.
# Set the working directory
# container/app/Rails
WORKDIR ${HOME}

# Copy the host(PC) files to the container
# COPY <Copy-Source>(host) <Copy-Destination>(container)
# Gemfile* ... Specify all files starting with Gemfile(Gemfile, Gemfile.lock)
# Copy Source(host) ... Specify the directory where the Dockerfile is located
# Copy Destination(container) ... Absolute path or relative path(./ ... current directory)
COPY Gemfile* ./

# apk: Alpine Linux command line package manager
    # update: Update the list of available packages
RUN apk update && \
    # upgrade: Upgrade all installed packages to their latest versions
    apk upgrade && \
    # add: Install packages
    # --no-cache: Do not cache the index of available packages
    apk add --no-cache ${RUNTIME_PACKAGES} && \
    # --virtual name(any name): Create a virtual package group for build-dependencies
    apk add --virtual build-dependencies --no-cache ${DEV_PACKAGES} && \
    # Install the bundler gem
    bundle lock --add-platform aarch64-linux && \
    # -j4(jobs4): Speeding up Gem installation
    bundle install -j4 && \
    # Remove the Package to reduce image size
    apk del build-dependencies

# . ... All files (subdirectories included) in the directory where the Dockerfile is located
COPY . ./

# Define the command you want to run in the container
# b ... Bind to all interfaces
CMD ["rails", "server", "-b", "0.0.0.0"]
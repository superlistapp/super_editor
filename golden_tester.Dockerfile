FROM ubuntu:latest

ENV FLUTTER_HOME=${HOME}/sdks/flutter 
ENV PATH ${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin

USER root

RUN apt update

RUN apt install -y git curl unzip

# Invalidate the cache when flutter pushes a new commit.
ADD https://api.github.com/repos/flutter/flutter/git/refs/heads/master ./flutter-latest-master

RUN git clone https://github.com/flutter/flutter.git ${FLUTTER_HOME}

RUN flutter doctor

# Copy the whole repo.
# We need this because we use local dependencies.
COPY ./ /super_editor



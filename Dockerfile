FROM zooniverse/ruby:2.1

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /src/

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y git

ADD ./ /src/

RUN mkdir -p data && cd lib && bundle install

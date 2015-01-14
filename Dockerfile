FROM zooniverse/ruby:2.1.2

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /src/

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y git

ADD ./ /src/

RUN cd lib && bundle install

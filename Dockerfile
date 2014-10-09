FROM ubuntu:12.04

ENV LANG en_US.UTF-8
ENV CONFIGURE_OPTS --disable-install-rdoc
ENV JRUBY_OPTS --2.0

WORKDIR /rails_app

ADD ./ /rails_app

# --no-install-recommends to avoid installing fuse (unsupported in docker < 1.0)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y openjdk-7-jre git-core curl build-essential && \
    git clone https://github.com/sstephenson/ruby-build.git && cd ruby-build && ./install.sh && \
    ruby-build jruby-1.7.13 /usr/local && rm -rf ruby-build && \
    gem install bundler && \
    bundle install --without test development && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

ENTRYPOINT /rails_app/start.sh

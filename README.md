# Panoptes ![Build Status](https://travis-ci.org/zooniverse/Panoptes.svg?branch=master)

The new Zooniverse API for supporting user-created projects.

## Documentation

The Panoptes public API is documented [here](http://docs.panoptes.apiary.io), using [apiary.io](http://apiary.io).

If you're interested in how Panoptes is implemented check out the [wiki](https://github.com/zooniverse/Panoptes/wiki).

* [Data Model Description](https://github.com/zooniverse/Panoptes/wiki/DataModel)

## Requirements

Panoptes is primarily developed against stable MRI, currently 2.2.1. It is tested against the following versions:

* JRuby 1.7.18
* 2.2.1

If you're running MRI Ruby you'll need to have the MySQL and Postgresql client libraries installed.

* Ubuntu/Debian: `apt-get install libpq-dev libmysqlclient`
* OS X (with [homebrew](http://homebrew.io)): `brew install mysql postgresql`

You'll need to have the following services running:

* [Postgresql](http://postgresql.org) version > 9.4
* [Zookeeper](http://zookeeper.apache.org) version > 3.4.6
* [Redis](http://redis.io) version > 2.8.19

Optionally you can run

* [Kafka](http://kafka.apache.org) version > 0.8.1.1
* [MySQL](http://www.mysql.com) version > 5.1

## Installation

We only support running Panoptes via Docker and Docker Compose. If you'd like to run it outside a container, see the above Requirements sections to get started.

It's possible to run Panoptes only having to install the `fig_rake` gem. Alternatives to various rake tasks are presented. 

### Setup Docker and Docker Compose

* Docker
  * [OS X](https://docs.docker.com/installation/mac/) - Boot2Docker
  * [Ubuntu](https://docs.docker.com/installation/ubuntulinux/) - Docker
  * [Windows](http://docs.docker.com/installation/windows/) - Boot2Docker

* [Docker Compose](https://docs.docker.com/compose/)

#### Usage

0. Clone the repository `git clone https://github.com/zooniverse/Panoptes`.

0. `cd` into the cloned folder. Run either `bundle install` or `gem install fig_rake`

0. Setup the application configuration files
  + Run: `find config/*.yml.hudson -exec bash -c 'for x; do x=${x#./}; cp -i "$x" "${x/.hudson/}"; done' _ {} +`

0. Setup the development Dockerfile
  + If you ran `bundle install`: `rake configure:dev_docker`
  + If you did not: `cp dockerfiles/Dockerfile.dev Dockerfile`

0. Install [Docker and Docker Compose](https://docs.docker.com/compose/install/).

0. Create and run the application containers by running `docker-compose up`

0. After step 5 finishes, open a new terminal and run `frake db:create db:migrate` to setup the database

0. To seed the development database with an Admin user and a Doorkeeper client application for API access run `frails runner db/fig_dev_seed_data/fig_dev_seed_data.rb` 

0. Open up the application in your browser:
  + If on a Mac, run `boot2docker ip` to get the IP-address where the server is running.
  + Visit either that address or just localhost on port 3000.

This will get you a working copy of the checked out code base. Keep your code up to date and rebuild the image if needed!

If you've added new gems you'll need to rebuild the docker image by running `docker-compose build`.

## Contributing

Thanks a bunch for wanting to help Zooniverse. Here are few quick guidelines to start working on our project:

0. Fork the Project on Github.
0. Clone the code and follow one of the above guides to setup a dev environment.
0. Create a new git branch and make your changes.
0. Make sure the tests still pass by running `bundle exec rspec`.
0. Add tests if you introduced new functionality.
0. Commit your changes. Try to make your commit message [informative](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html), but we're not sticklers about it. Do try to to add `Closes #issue` or `Fixes #issue` somewhere in your message if it's addressing a specific open issue.
0. Submit a Pull Request
0. Wait for feedback or a merge!

Your Pull Request will run on [travis-ci](https://travis-ci.org/zooniverse/Panoptes), and we'll probably wait for it to pass on MRI Ruby 2.2.1 and JRuby 1.7.18 before we take a look at it.

## License

Copyright 2014-2015 by the Zooniverse

Distributed under the Apache Public License v2. See LICENSE

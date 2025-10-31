#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

sudo -u www-data bash -c "
source $RVM_SOURCE ;\
rvm $RVM;\
bundle exec rails console staging"

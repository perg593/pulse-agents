#!/bin/bash
export APP_NAME=pi
export APP_ENV=production
export RUBY_VERSION=ruby-3.3.4
export DEPLOY_TO=/var/www/production/pi
export COFFEESCRIPT_SOURCE_PATH=$DEPLOY_TO/vendor/assets/javascripts/coffeescript.js
export RVM=ruby-3.3.4@pi_production
export RVM_SOURCE=/usr/local/lib/rvm
export USER=www-data
export GROUP=www-data
export GEM_PATH=/usr/local/rvm/gems/$RUBY_VERSION:/usr/local/rvm/gems/$RUBY_VERSION@global:/usr/local/rvm/gems/$RVM
export GEM_HOME=/usr/local/rvm/gems/$RVM
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/:$GEM_PATH
export HOME=/var/www
export RAILS_ENV=$APP_ENV
export VERBOSE=true

#echo "APP_NAME:"$APP_NAME
#echo "APP_ENV:"$APP_ENV
#echo "DEPLOY_TO:"$DEPLOY_TO
#echo "RVM:"$RVM
#echo "ENV:"
#env

cd $DEPLOY_TO/current
source $RVM_SOURCE
rvm $RVM
umask 0002

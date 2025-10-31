#! /bin/bash

# TODO: Create a template that each env can use

source /var/www/develop/pi/shared/scripts/env.sh

PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/root

export PATH=$PATH
export HOME=$HOME
INDEX="$2"

cd $DEPLOY_TO/current/rack
source $RVM_PATH
rvm $RVM
umask 0002

PID_FILE=$DEPLOY_TO/shared/pids/thin.rack.$INDEX.pid
SOCKET=$DEPLOY_TO/shared/sockets/thin.rack.$INDEX.socket

LOG_FILE=$DEPLOY_TO/shared/log/serving.$INDEX.log
THIN_LOG_FILE=$DEPLOY_TO/shared/log/thin.serving.$INDEX.log
export LOG_FILE=$LOG_FILE

case "$1" in
  start)
    echo "Starting rack $INDEX.."
    bundle exec thin start -d -q -l $THIN_LOG_FILE -R ./config.ru -e $RAILS_ENV -P $PID_FILE -c $DEPLOY_TO/current/rack --user $USER --group $GROUP -S $SOCKET
    echo "Done!"
    ;;
  stop)
    echo "Stopping thin $INDEX.."
    bundle exec thin stop -P $PID_FILE
    echo "Done"
    ;;
  *)
    echo "Usage: thin_server {start|stop} {server_index}"
    exit 1
    ;;
esac
exit 0

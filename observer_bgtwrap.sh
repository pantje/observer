#!/bin/sh
# this is <observer_bgtwrap.sh>
# ----------------------------------------------------------------------------
# $Id: observer_bgtwrap.sh,v 1.3 2008-11-27 21:28:44 tforb Exp $
# 
# Copyright (c) 2008 by Thomas Forbriger (BFO Schiltach) 
# 
# call twrap in true background
# 
# REVISIONS and CHANGES 
#    27/11/2008   V1.0   Thomas Forbriger
# 
# ============================================================================
#

OBS_WRAP_LOGDIR=$HOME/tmp/observer
mkdir -pv $OBS_WRAP_LOGDIR
LOGFILE=$OBS_WRAP_LOGDIR/bgwrapper.log

if test $# -lt 1 
then
  echo "Usage; $0 wrapper plugin [plugin ...]"
  echo
  echo "wrapper   path to observer_twrap.sh"
  echo "plugin    path to observer plugin to execute"
  exit 2
fi

WRAPPER=$1
shift

if test ! -x $WRAPPER
then
  echo $WRAPPER is not executable!
  exit 3
fi

while test -n "$1"
do
  PLUGIN=$1
  if test -x $PLUGIN
  then
    $WRAPPER $PLUGIN 2>&1 >$LOGFILE
    ( echo ; \
      echo "-------------------------------"; \
      echo "output interpreted by observer:"; \
      echo "-------------------------------"; \
      echo ; \
      /bin/cat $LOGFILE | egrep "^(status|message): "; \
      cat $LOGFILE ) | mail -s "$(basename $0) $(basename $PLUGIN)" $USER
  else
    echo $PLUGIN | mail -s "ERROR: plugin $(basename $PLUGIN) not executable" $USER
  fi
  shift
  exit
done

# ----- END OF observer_bgtwrap.sh ----- 

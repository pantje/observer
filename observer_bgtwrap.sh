#!/bin/sh
# this is <observer_bgtwrap.sh>
# ----------------------------------------------------------------------------
# 
# Copyright (c) 2008 by Thomas Forbriger (BFO Schiltach) 
# 
# call twrap in true background
#
# ----
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. 
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# ----
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
      echo;  \
      cat $LOGFILE; \
      echo ) | mail -s "$(basename $0) $(basename $PLUGIN)" $USER
  else
    echo $PLUGIN | mail -s "ERROR: plugin $(basename $PLUGIN) not executable" $USER
  fi
  shift
  exit
done

# ----- END OF observer_bgtwrap.sh ----- 

#!/bin/sh
# this is <observer_twrap.sh>
# ----------------------------------------------------------------------------
# $Id$
# 
# Copyright (c) 2003 by Thomas Forbriger (BFO Schiltach) 
# 
# test wrapper for observer plugins
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
#    22/06/2003   V1.0   Thomas Forbriger
#    19/08/2003   V1.1   allow us to watch the progress
# 
# ============================================================================
#

if test $# -lt 1
then
  echo $0
  echo Usage: $(basename $0) plugin
  echo
  echo plugin     name of an observer plugin
  echo
  echo This wrapper provides all environment variables provided by the
  echo observer.
  exit 1
fi

OBS_WRAP_LOGDIR=$HOME/tmp/observer

PWD=$(pwd)
OBS_WRAP_PLUGIN=$1
OBS_WRAP_PLUGIN_BASE=$(basename $OBS_WRAP_PLUGIN)
OBS_WRAP_PLUGIN_DIR=$(dirname $OBS_WRAP_PLUGIN)

export  OBS_CLIENT=$USER
export  OBS_LOG_DIR="$OBS_WRAP_LOGDIR"
export  OBS_SCRIPT_DIR="$OBS_WRAP_PLUGIN_DIR"
export  OBS_LOG=$OBS_WRAP_LOGDIR/$OBS_WRAP_PLUGIN_BASE.log
export  OBS_SCRIPT=$OBS_WRAP_PLUGIN

export  OBS_KEY_STATUS="status:"
export  OBS_KEY_MESSAGE="message:"

export  OBS_KEY_OK="O"
export  OBS_KEY_NOTICE="N"
export  OBS_KEY_ALERT="A"
  
export  OBS_STATUS_OK="$OBS_KEY_STATUS $OBS_KEY_OK"
export  OBS_STATUS_NOTICE="$OBS_KEY_STATUS $OBS_KEY_NOTICE"
export  OBS_STATUS_ALERT="$OBS_KEY_STATUS $OBS_KEY_ALERT"

OBS_WRAP_OUTLOG=$OBS_LOG_DIR/stderr.out

echo "This is "'$Id$'
echo "======================================================================"
echo "wrapped plugin: $OBS_WRAP_PLUGIN"
echo
echo non-standard settings passed to plugin:
echo  OBS_CLIENT=$USER
echo  OBS_LOG_DIR="$OBS_WRAP_LOGDIR"
echo  OBS_SCRIPT_DIR="$OBS_WRAP_PLUGIN_DIR"
echo  OBS_LOG=$OBS_WRAP_LOGDIR/$OBS_WRAP_PLUGIN_BASE.log
echo  OBS_SCRIPT=$OBS_WRAP_PLUGIN
echo

# go
/bin/rm -fv $OBS_WRAP_OUTLOG $OBS_LOG
OBS_WRAP_START=$(date)
/bin/mkdir -pv $OBS_WRAP_LOGDIR

if test $# -gt 1
then 
  echo "$OBS_WRAP_PLUGIN 2>&1 | tee $OBS_WRAP_OUTLOG"
  $OBS_WRAP_PLUGIN 2>&1 | tee $OBS_WRAP_OUTLOG
else
  echo "$OBS_WRAP_PLUGIN >$OBS_WRAP_OUTLOG 2>&1"
  $OBS_WRAP_PLUGIN >$OBS_WRAP_OUTLOG 2>&1
fi 
OBS_WRAP_FINISH=$(date)

# report
echo 
echo "logfile $OBS_LOG:"
echo "---------------------------------------------"
/bin/cat $OBS_LOG
echo 
echo "--------------------------"
echo "output passed to observer:"
echo "--------------------------"
/bin/cat $OBS_WRAP_OUTLOG | egrep -v "^(status|message): " 
echo 
echo "-------------------------------"
echo "output interpreted by observer:"
echo "-------------------------------"
/bin/cat $OBS_WRAP_OUTLOG | egrep "^(status|message): " 

echo
echo "======================================================================="
echo " script started: $OBS_WRAP_START"
echo "script finished: $OBS_WRAP_FINISH"

# ----- END OF observer_twrap.sh ----- 

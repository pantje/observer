#!/bin/sh
# this is <observer_bgtwrap.sh>
# ----------------------------------------------------------------------------
# $Id: observer_bgtwrap.sh,v 1.1 2008-11-27 20:47:26 tforb Exp $
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

while test -x $1
do
  PLUGIN=$1
  $WRAPPER $PLUGIN 2>&1 | mail -s "$(basename $0) $PLUGIN" $USER
  shift
done

# ----- END OF observer_bgtwrap.sh ----- 

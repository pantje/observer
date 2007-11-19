#!/usr/bin/perl
# this is <observer_mkdir.pl>
# ----------------------------------------------------------------------------
#
# 18/01/00 by Thomas Forbriger (IfG Stuttgart)
#
# create client directory structure for observer.pl
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
#    18/01/00   V1.0   Thomas Forbriger
#
# ============================================================================
#

# called program name
# -------------------
$OBSERVER_NAME=$0;

# default config file
# -------------------
$DEFAULT_CONFIG="$ENV{HOME}/observer/observer.cfg";

# check environment for config file setting
# -----------------------------------------
if ( -r $ENV{OBSERVER_CONFIG} && -T $ENV{OBSERVER_CONFIG} ) {
  $CONFIG_FILE=$ENV{OBSERVER_CONFIG}
} else {
  $CONFIG_FILE=$DEFAULT_CONFIG
}

# read config file
# ----------------
do $CONFIG_FILE or die "ERROR: reading config file $CONFIG_FILE\n";

# ============================================================================
#
# define subroutines
# ==================

# fatal error condition
# ---------------------
sub FATAL_ERROR {
  $string="ERROR ($OBSERVER_NAME): @_";
  system "/bin/echo \"$string\" | mail -s \"ERROR: $OBSERVER_NAME\" $OBSERVER_NOTIFY";
  die "$string\n";
}

# check directory name
# --------------------
sub CHECK_DIR {
  for (@_) {
    if ( ! ( -d $_ && -r $_ && -x $_ )) {
      FATAL_ERROR("\n  directory $_\n  is unusable!");
    }
  }
}

# ============================================================================
#
# continue main code
# ==================

# now scan all clients
# --------------------
foreach $client (keys(%OBSERVER_CLIENT)) {
  $OBSERVER_CLDIR=$OBSERVER_CLIENT{$client};
  printf ("\ncreate directories for client %s:\n", $client);
  foreach $interval (keys(%OBSERVER_OKREPORT)) {
    $command=sprintf("su %s -s /bin/bash -c \"/bin/mkdir -p %s/scripts/%s\"",
      $client, $OBSERVER_CLDIR, $interval);
    printf ("%s\n", $command);
    system($command);
    $command=sprintf("su %s -s /bin/bash -c \"/bin/mkdir -p %s/log/%s\"",
      $client, $OBSERVER_CLDIR, $interval);
    printf ("%s\n", $command);
    system($command);
  }
}

#
# ----- END OF observer_mkdir.pl ----- 

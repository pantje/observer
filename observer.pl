#!/usr/bin/perl
# this is <observer.pl>
# ----------------------------------------------------------------------------
#
# $Source: /home/tforb/svnbuild/cvssource/CVS/thof/scr/adm/observer/observer.pl,v $
# $Id: observer.pl,v 1.8 2000-08-15 08:21:54 thof Exp $
#
# 17/01/00 by Thomas Forbriger (IfG Stuttgart)
#
# This is the main tool for observing services
#
# Use this as observer.hourly.pl, observer.daily.pl observer.weekly.pl
# and observer.monthly.pl
#
# REVISIONS and CHANGES
#    17/01/00   V0.1   Thomas Forbriger
#    19/01/00   V1.0   first released Version
#    21/01/00   V1.1   introduced report level check for mail
#    25/01/00   V1.2   changed reporting scheme
#    21/02/00   V1.3   changed differences reporting scheme
#                      (was not working in former version)
#    22/02/00   V1.4   change to users home directory before calling /bin/su
#    07/03/00   V1.5   now reports new lines
#    31/07/00   V1.6   now uses /bin/bash as su login shell
#    15/08/00   V1.7   day-value in tm struct has range from 1 to 31
#
# ============================================================================
#
# we aren't using Sys::Syslog as I did not managed to get any message through
#use Sys::Syslog;

$VERSION="OBSERVER   V1.7   central service";

# called program name
# -------------------
$OBSERVER_NAME=$0;

# ----------------------------------------------------------------------------
# static configs
# ==============
# 
# default config file
# -------------------
$DEFAULT_CONFIG="$ENV{HOME}/observer/observer.cfg";
#
# syslog priority
$SYSLOG_FACILITY  ="user";
$SYSLOG_ALERT     ="$SYSLOG_FACILITY.alert";
$SYSLOG_NOTICE    ="$SYSLOG_FACILITY.notice";
$SYSLOG_OK        ="$SYSLOG_FACILITY.info";
#
# status levels
$STATUS_ALERT  ="A";
$STATUS_NOTICE ="N";
$STATUS_OK     ="O";
#
# external binaries
# -----------------
$binECHO    ="/bin/echo";
$binSU      ="/bin/su";
$binBASH    ="/bin/bash";
$binLOGGER  ="/usr/bin/logger";
$binMAIL    ="/usr/bin/mail";
#
# ----------------------------------------------------------------------------

# check environment for config file setting
# -----------------------------------------
if ( -r $ENV{OBSERVER_CONFIG} && -T $ENV{OBSERVER_CONFIG} ) {
  $CONFIG_FILE=$ENV{OBSERVER_CONFIG}
} else {
  $CONFIG_FILE=$DEFAULT_CONFIG
}

# read config file
# ----------------
do $CONFIG_FILE or die "ERROR: reading config file $CONFIG_FILE: $!\n";

# ============================================================================
#
# define subroutines
# ==================

# log a message (to syslog) - generic code
# ----------------------------------------
sub GENERICLOG {
  $loglevel=shift;
  open (syslog, "|$binLOGGER -p $loglevel -t $OBSERVER_NAME\\[$$\\]")
    or FATAL_ERROR("could not open syslog: $!");
  for (@_) { print syslog "$_\n"; }
  close syslog;
##  for (@_) { syslog('notice', "%s\n", $_) }
}

# log a message (to syslog)
# -------------------------
sub LOG { GENERICLOG($SYSLOG_OK, @_); }

# log a noticeable message (to syslog)
# ------------------------------------
sub NOTICELOG { GENERICLOG($SYSLOG_NOTICE, @_); }

# log an error message (to syslog)
# --------------------------------
sub ERRLOG { GENERICLOG($SYSLOG_ALERT, @_); }

# fatal error condition
# ---------------------
sub FATAL_ERROR {
  $title="FATAL ERROR in $OBSERVER_NAME\[$$\]:";
  ERRLOG($title, @_);
  for ($title, @_) { print stderr "$_\n"; }
  $command=sprintf("|%s -s \"FATAL ERROR: %s\" %s",
    $binMAIL, $OBSERVER_NAME, $OBSERVER_NOTIFY);
  open(MAIL,$command) or die "could not open \'$command\': $!\n";
  print MAIL "$title\n\n";
  for (@_) { print MAIL "$_\n"; }
  close(MAIL);
  die "...this is a fatal error...\n";
}

# check file permissions and ownership
# ------------------------------------
#
# We should have a close look at these values as we will change the effective
# UID. If there is any other user haveing write access to file that will be
# executed under foreign privileges this will be a severe security hole.
sub CHECK_FILE {
  $client=shift;
  $clientuid=shift;
  $clientgid=shift;
  foreach (@_) {
    @statentries=stat("$_");
    if ($#statentries < 0) {
      FATAL_ERROR("ERROR: could not stat $scriptpath!");
    }
    $fileuid=$statentries[4];
    $filegid=$statentries[5];
    $filemode=$statentries[2];
##    printf("uid %s\ngid %s\nmode %s\n",
##      $fileuid, $filegid, $filemode);
##    for (@statentries) { printf("%s, ",$_);} ; printf("\n");
    if ($fileuid != $clientuid) {
      FATAL_ERROR("ERROR: $client does not own $_!");
    }
    if ($filegid != $clientgid) {
      FATAL_ERROR("ERROR: $_ is not in $client group!");
    }
##    $val=(($filemode + 0) & 06022);
    if ((("$filemode" + 0) & 06022) > 0) {
##      printf("mode: %o   and-mode: %o\n", $filemode, $val);
      FATAL_ERROR((sprintf("ERROR: %s",
        $_), sprintf("has insecure mode: (%o)!", $filemode)));
    }
  }
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

# format status output
# --------------------
sub STATUS_FORM {
  return sprintf("%1.1s %10.10s %14.14s %s", $_[0], $_[1], $_[2], $_[3]);
}

# ============================================================================
#
# continue main code
# ==================
#openlog($OBSERVER_NAME, "pid", $SYSLOG_FACILITY);
LOG "entered $VERSION";

# check definitions
# -----------------
unless ( defined %OBSERVER_CLIENT ) {
  FATAL_ERROR("config hash \$OBSERVER_CLIENT undefined!"); }
unless ( defined %OBSERVER_OKREPORT ) {
  FATAL_ERROR("config hash \$OBSERVER_OKREPORT undefined!"); }
unless ( defined $OBSERVER_NOTIFY ) {
  FATAL_ERROR("config variable \$OBSERVER_NOTIFY undefined!"); }
unless ( defined $OBSERVER_LOGDIR ) {
  FATAL_ERROR("config variable \$OBSERVER_LOGDIR undefined!"); }

# check log path
# --------------
unless ( -d $OBSERVER_LOGDIR && -x $OBSERVER_LOGDIR && -w $OBSERVER_LOGDIR ) {
  FATAL_ERROR("log dir $OBSERVER_LOGDIR is unusable!"); }

# check interval level
# --------------------
$OBSERVER_INTERVAL="NIL";
foreach $interval (keys(%OBSERVER_OKREPORT)) {
  if ($OBSERVER_NAME =~ m/$interval/) {
#    printf ("I am %s!\n", $interval);
    $OBSERVER_INTERVAL=$interval;
  }
}
$OBSERVER_INTERVAL =~ m/^NIL$/ and FATAL_ERROR("illegal interval!"); 
#printf ("Interval is: %s\n", $OBSERVER_INTERVAL);

# ====================
# now scan all clients
# ====================

# initialize report arrays
# ------------------------
@OUTPUT_REPORT=();  # script output
@STATUS_REPORT=();  # status message lines
@ERROR_REPORT=();   # non-fatal errors

# cycle through client list
# =========================
foreach $client (keys(%OBSERVER_CLIENT)) {

# check client
  @pwentries=getpwnam($client);
  if ($#pwentries < 0) {
    FATAL_ERROR("ERROR: $client is unknown to /etc/passwd!");
  }
##  for (@pwentries) { print "$_\n"; }
  $CLIENTUID=$pwentries[2];
  $CLIENTGID=$pwentries[3];
  $CLIENTHOME=$pwentries[7];
##  print "$CLIENTUID $CLIENTGID\n";
  if ($CLIENTUID == 0) {
    NOTICELOG("$client has UID $CLIENTUID!");
    $CALLCMD="$binBASH -c ";
  } else {
    $CALLCMD="cd $CLIENTHOME; $binSU $client -s $binBASH -c ";
  }

# set directories
  $OBSERVER_CLDIR=$OBSERVER_CLIENT{$client};
  $OBS_SCRIPT_DIR="$OBSERVER_CLDIR/scripts/$OBSERVER_INTERVAL";
  $OBS_LOG_DIR="$OBSERVER_CLDIR/log/$OBSERVER_INTERVAL";
  CHECK_DIR("$OBSERVER_CLDIR", "$OBS_SCRIPT_DIR", "$OBS_LOG_DIR");
##  printf ("script dir: %s\n",$OBS_SCRIPT_DIR);

# check directory for correct file attributes
  CHECK_FILE($client, $CLIENTUID, $CLIENTGID, $OBS_SCRIPT_DIR);

# scan script directory
# ---------------------
  opendir (scriptdir, $OBS_SCRIPT_DIR) 
    or FATAL_ERROR("ERROR: could not open $OBS_SCRIPT_DIR: $!");
  @scripts = grep { 
      (!m/\.bak$/) 
      && -f "$OBS_SCRIPT_DIR/$_"
      && -x "$OBS_SCRIPT_DIR/$_"
    } readdir(scriptdir);
  closedir(scriptdir);

# cycle thorugh scripts
# ---------------------
  foreach $script (@scripts) {

# check script for correct file attributes
    CHECK_FILE($client, $CLIENTUID, $CLIENTGID, "$OBS_SCRIPT_DIR/$script");

# set up environment
    $ENV{OBS_KEY_STATUS}   ="status:";
    $ENV{OBS_KEY_MESSAGE}  ="message:";
    $ENV{OBS_KEY_OK}       =$STATUS_OK;
    $ENV{OBS_KEY_NOTICE}   =$STATUS_NOTICE;
    $ENV{OBS_KEY_ALERT}    =$STATUS_ALERT;
    $ENV{OBS_STATUS_OK}    ="status: $STATUS_OK";
    $ENV{OBS_STATUS_NOTICE}="status: $STATUS_NOTICE";
    $ENV{OBS_STATUS_ALERT} ="status: $STATUS_ALERT";
    $ENV{OBS_CLIENT}       =$client;
    $ENV{OBS_SCRIPT}       =$script;
    $ENV{OBS_SCRIPT_DIR}   =$OBS_SCRIPT_DIR;
    $ENV{OBS_LOG_DIR}      =$OBS_LOG_DIR;
    @ltime=localtime;
    $ENV{OBS_LOG}=sprintf("%s/%s_%.4d_%.2d_%.2d_%.2d.log", 
      $OBS_LOG_DIR, $script,
      $ltime[5]+1900, $ltime[4]+1, $ltime[3], $ltime[2]);

# initialize report variables
    $STATUS_LEVEL="";
    $STATUS_MESSAGE="";

# set up command string to be opened
    $command=sprintf("%s \"%s/%s\" 2>&1 |", 
      $CALLCMD, $OBS_SCRIPT_DIR, $script);

    LOG "open \'$command\'";

# prepare output log
    @thisout=();
##    printf("init: %d\n",$#thisout);

# open command and read output from command
    open(COMMAND, $command) or 
      FATAL_ERROR("ERROR: could not open: $command: $!\n");
    while (<COMMAND>) {
      chomp;
      if (/^\s*status:/) { 
        $STATUS_LEVEL="$'";
        $STATUS_LEVEL=~ s/^\s*//;
      } elsif (/^\s*message:/) {
        $STATUS_MESSAGE="$'";
        $STATUS_MESSAGE=~ s/^\s*//;
      } else {
        push @thisout, $_;
      }
##      printf("%s(%d): %s\n",$script,$#thisout,$_);
    }
    close(COMMAND);

# append output to report (in case there is any)
    if ($#thisout >= 0) {
      push @OUTPUT_REPORT, "$script of $client produced output:";
      push @OUTPUT_REPORT, "($command)";
      for (@thisout) { push @OUTPUT_REPORT, "> $_"; }
      push @OUTPUT_REPORT, " ";
    }

##    print "status: $STATUS_LEVEL $STATUS_MESSAGE\n";
# check status report of this service
    $Read_Level=$STATUS_LEVEL;
    $STATUS_LEVEL="";
    foreach $key ($STATUS_OK, $STATUS_NOTICE, $STATUS_ALERT) {
      if ($Read_Level =~ /^\s*$key\s*$/) { $STATUS_LEVEL=$key; }
    }
    if (($STATUS_LEVEL =~ m/^\s*$/) || ($STATUS_MESSAGE =~ m/^\s*$/)) {
      @thisout=("ERROR in status report:",
        "$script of $client returned incomplete status!",
        "($command)");
      if ($STATUS_LEVEL =~ m/^\s*$/) {
        push @thisout, 
          (sprintf("status level (%s) is not set (regex \"^status:\")",
             $Read_Level),
           sprintf("  or incorrect (valid keys: %s, %s, %s)",
             $STATUS_OK,$STATUS_NOTICE, $STATUS_ALERT));
        $STATUS_LEVEL=$STATUS_ALERT;
      }
      if ($STATUS_MESSAGE =~ m/^\s*$/) {
        push @thisout, "status message is not set (regex \"^message:\")";
        $STATUS_MESSAGE="**** MISSING ****";
      }
      ERRLOG(@thisout);
##      for (@thisout) { print "$_\n"; };
      push @ERROR_REPORT, (@thisout," ");
    }
##    print "status: $STATUS_LEVEL $STATUS_MESSAGE\n";

# remember status
    push @STATUS_REPORT, [($client, $script, $STATUS_LEVEL, $STATUS_MESSAGE)];
  } # end of script cycle
} # end of client cycle

# ===================
# now log all reports
# ===================

# set log file names
@ltime=localtime;
$logname=sprintf("%s/%s_%.4d_%.2d_%.2d_%.2d", 
  $OBSERVER_LOGDIR, $OBSERVER_INTERVAL,
  $ltime[5]+1900, $ltime[4]+1, $ltime[3]+1, $ltime[2]);
$LOG_MASTER     ="$logname.log";
$LOG_PREVSTATUS ="$OBSERVER_LOGDIR/prevstatus.$OBSERVER_INTERVAL.log";
$LOG_STATUS     ="$logname.status";

# create status file from status report
@STATUS_FILE=();
for $stline (@STATUS_REPORT) { 
  push @STATUS_FILE, 
    STATUS_FORM($$stline[2], $$stline[0], $$stline[1], $$stline[3]);
};

# compare with previous status report
# -----------------------------------
@PREVIOUS_STATUS=();
@STATUS_DIFF=();
@STATUS_NEW=();
if (-r $LOG_PREVSTATUS) {
  if (open(PREVSTATUS, "<$LOG_PREVSTATUS")) {
# read previous
    @PREVIOUS_STATUS=(<PREVSTATUS>);
    close(PREVSTATUS);
    chomp(@PREVIOUS_STATUS);
#
# ---
# create differences (what was in old status that is not in current one)
# ---
#
# create a working copy of the current status
    @current_status=@STATUS_FILE;
# take each line of previous status
    foreach $stline (sort (@PREVIOUS_STATUS)) {
# remember line and remove meta characters
      $orline = $stline;
      $stline =~ tr/*.?+//d;
##      print "$stline\n";
# search for this pattern in current status
# the extra '$_' is necessary as map evaluates in list context
# without map would return the number of tr-substitutions
      @matching=grep { m/^$stline$/ } map { tr/*.?+//d; $_; } (@current_status);
##      print "$#matching\n";
      if ($#matching < 0) {
        push @STATUS_DIFF, $orline;
      }
    }
# so, are there any differences now?
    if ($#STATUS_DIFF < 0) {
      $DIFFERENCES=0;
      @STATUS_DIFF="none"; i
    } else {
      $DIFFERENCES=1;
    }
#
# ---
# create new (what was in current status that is not in old one)
# ---
#
# create a working copy of the current status
    @current_status=@STATUS_FILE;
    @previous_status=@PREVIOUS_STATUS;
# take each line of previous status
    foreach $stline (sort (@current_status)) {
# remember line and remove meta characters
      $orline = $stline;
      $stline =~ tr/*.?+//d;
##      print "$stline\n";
# search for this pattern in current status
# the extra '$_' is necessary as map evaluates in list context
# without map would return the number of tr-substitutions
      @matching=grep { m/^$stline$/ } map { tr/*.?+//d; $_; }
        (@previous_status);
##      print "$#matching\n";
      if ($#matching < 0) {
        push @STATUS_NEW, $orline;
      }
    }
# so, are there any differences now?
    if ($#STATUS_NEW < 0) {
      $NEW=0;
      @STATUS_NEW="none"; i
    } else {
      $NEW=1;
    }
  } else {
    @STATUS_DIFF=("could not open $LOG_PREVSTATUS: $!");
    ERRLOG(@STATUS_DIFF);
    @STATUS_NEW=@STATUS_FILE;
    $NEW=1;
  } # if open
} else {
  @STATUS_DIFF=("There was no previous status log found...");
  ERRLOG(@STATUS_DIFF);
  @STATUS_NEW=@STATUS_FILE;
  $NEW=1;
} # if -r

$now_time=localtime;

# write status file
# -----------------
if (open(STATUSFILE, ">>$LOG_STATUS")) {
  printf STATUSFILE ("%s\n", $now_time);
  for (@STATUS_FILE) { print STATUSFILE "$_\n"; }
  close(STATUSFILE);
} else {
  $error="could not open $LOG_STATUS: $!";
  push @ERROR_REPORT, ($error, " ");
  ERRLOG($error);
}

# write "previous" status file
# ----------------------------
if (open(STATUSFILE, ">$LOG_PREVSTATUS")) {
  for (@STATUS_FILE) { print STATUSFILE "$_\n"; }
  close(STATUSFILE);
} else {
  $error="could not open $LOG_PREVSTATUS: $!";
  push @ERROR_REPORT, ($error, " ");
  ERRLOG($error);
}

# prepare full report
# -------------------
@OBSERVER_REPORT=();

@STATUS_HEAD=(STATUS_FORM(("S","user","service","message")),
  STATUS_FORM("---","--------------------------",
    "-------------------------------",
    substr("--------------------------------------------------------", 1,46)));

# find status level
$MASTER_LEVEL="OK";
@STLINES_OK     =grep { m/^$STATUS_OK / }     sort(@STATUS_FILE);
@STLINES_NOTICE =grep { m/^$STATUS_NOTICE / } sort(@STATUS_FILE);
@STLINES_ALERT  =grep { m/^$STATUS_ALERT / }  sort(@STATUS_FILE);
@TELL_OK=();
@TELL_NOTICE=();
@TELL_ALERT=();
if ($#STLINES_OK     >= 0) {
  @TELL_OK=("OK level:",     @STATUS_HEAD, @STLINES_OK, " ");
}
if ($#STLINES_NOTICE >= 0) { 
  $MASTER_LEVEL="NOTICE"; 
  @TELL_NOTICE=("NOTICE level:", @STATUS_HEAD, @STLINES_NOTICE, " ");
}
if ($#STLINES_ALERT  >= 0) { 
  $MASTER_LEVEL="ALERT";  
  @TELL_ALERT=("ALERT level:",  @STATUS_HEAD, @STLINES_ALERT, " ");
}

@TELL_ERRORS=();
if ($#ERROR_REPORT   >= 0) { 
    $MASTER_LEVEL="ALERT"; 
    @TELL_ERRORS=("ERRORS:", 
                  "-------", @ERROR_REPORT, " ");
  }

# do we have to send an e-mail?
$master_level_index=substr($MASTER_LEVEL,0,1);
$mail_level_indices=$OBSERVER_OKREPORT{$OBSERVER_INTERVAL};
if ($mail_level_indices =~ m/$master_level_index/) {
  $mail_comment="(sent to $OBSERVER_NOTIFY)";
  $mail_it=1;
} else {
  $mail_comment="(no mail sent)";
  $mail_it=0;
}

# build report
@OBSERVER_REPORT=
  ($OBSERVER_VERSION, " ",
   sprintf("This is the %s report at %s", $OBSERVER_INTERVAL, $now_time),
   "The status of this report is: $MASTER_LEVEL $mail_comment", " ",
   @TELL_ERRORS,
   "Client status messages:",
   "=======================",
   sprintf("%.10s: Exit status (%s: OK; %s: NOTICE; %s: ALERT)",
     "S", $STATUS_OK, $STATUS_NOTICE, $STATUS_ALERT), " ");

if ($NEW) {
  push @OBSERVER_REPORT,
    ("NEW LINES IN CURRENT RUN:",
     "(i.e. lines that appeared in current one but not in previous one)",
     @STATUS_HEAD, @STATUS_NEW, " ", "This run:");
}

push @OBSERVER_REPORT,
  (@STATUS_HEAD, @STLINES_ALERT, @STLINES_NOTICE, @STLINES_OK);

if ($DIFFERENCES) {
  push @OBSERVER_REPORT,
    (" ","DIFFERENCES TO PREVIOUS RUN:",
     "(i.e. lines that appeared in previous one but not in this one)",
     @STATUS_HEAD, @STATUS_DIFF);
}

if (! $NEW) {
  push @OBSERVER_REPORT,
  (" ","No new lines compared to previous run...");
}

if (! $DIFFERENCES) {
  push @OBSERVER_REPORT,
  (" ","No differences to previous run...");
}

push @OBSERVER_REPORT, (" ", 
  "Reports from client services:",
  "=============================", @OUTPUT_REPORT);

# write full report
# -----------------
open(FULLREPORT, ">>$LOG_MASTER") or
  FATAL_ERROR("could not open $LOG_MASTER: $!", @OBSERVER_REPORT);
for (@OBSERVER_REPORT) { print FULLREPORT "$_\n"; }
close(FULLREPORT);

# mail full report
# ----------------
if ($mail_it) {
  $command=sprintf("|%s -s \"%s: %s observer at %s\" %s",
    $binMAIL, $MASTER_LEVEL, $OBSERVER_INTERVAL,
    $now_time, $OBSERVER_NOTIFY);
  open(MAIL,$command) or 
    FATAL_ERROR("could not open \'$command\': $!\n", @OBSERVER_REPORT);
  for (@OBSERVER_REPORT) { print MAIL "$_\n"; }
  close(MAIL);
}

LOG "finished $VERSION";
exit(0);
#
# ----- END OF observer.pl ----- 

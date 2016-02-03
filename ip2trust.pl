#!/usr/bin/perl
# ======================================================
# Writer   : Mico Cheng
# Version  : 20040910
# Use for  : transfer IP Class to TrustIP Table
# ======================================================

use DBI;

$accessfile = "relay.list";

$dbh = DBI->connect("DBI:mysql:mail_db;host=127.0.0.1", "rmail", "LykCR3t1") or die "$!\n";

&insertip("127.0.0.1");

open ACCESS, "$accessfile" or die "Can not open $accessfile:$!\n";
while (<ACCESS>) {
print "line: $_\n";
      if (/^(\d+\.\d+\.\d+\.\d+)\s+(RELAY|OK)$/) {
            #print "insert $trustip\n";
            &insertip($1);
      } elsif (/^(\d+\.\d+\.\d+)\s+(RELAY|OK)$/) {
            @range = 1..254;
            $trustcip = $1;
            foreach $one (@range) {
                   $trustip = "$trustcip."."$one";
                   #print "insert $trustip\n";
                   insertip($trustip);
            }
      } elsif (/^(\d+\.\d+)\s+RELAY/) {
            @range_a = 0..254;
            @range_b = 1..254;
            $trustbip = $1;
            foreach $one (@range_a) {
                 foreach $two (@range_b) {
                        $trustip = "$trustbip."."$one."."$two";
                        #print "insert $trustip\n";
                        insertip($trustip);
                 }
            }
      } else {
            print "no match RELAY:$_\n";
      }
}
$dbh->disconnect();
close(ACCESS);

sub insertip {
#  $sqlstmt = sprintf("select s_ip from TrustIP where s_ip=\'%s\'", $_[0]);
#  $sth = $dbh->prepare($sqlstmt);
#  $sth->execute() or die "can not insert : $!\n";
#  if ($sth->rows != 1) {
        $sqlstmt = sprintf("insert into TrustIP values ('%s', NOW(), 'add by mico')", $_[0]);
        $dbh->do($sqlstmt);
#  } else {
#        next;
#  }
}

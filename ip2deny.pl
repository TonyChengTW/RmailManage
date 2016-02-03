#!/usr/bin/perl
# ======================================================
# Writer   : Mico Cheng
# Version  : 20040910
# Use for  : transfer IP Class to DenyIP Table
# ======================================================

use DBI;

$accessfile = shift;

$dbh = DBI->connect("DBI:mysql:mail_db;host=127.0.0.1", "rmail", "LykCR3t1") or die "$!\n";

open ACCESS, "$accessfile" or die "Can not open $accessfile:$!\n";
while (<ACCESS>) {
print "line: $_\n";
      if (/^(\d+\.\d+\.\d+\.\d+)$/) {
            #print "insert $trustip\n";
            &insertip($1);
      } elsif (/^(\d+\.\d+\.\d+)$/) {
            @range = 1..254;
            $trustcip = $1;
            foreach $one (@range) {
                   $trustip = "$trustcip."."$one";
                   #print "insert $trustip\n";
                   insertip($trustip);
            }
      } elsif (/^(\d+\.\d+)/) {
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
        $sqlstmt = sprintf("insert into DenyIP values ('%s', NOW(), 'spammer from 62 access-list')", $_[0]);
        $dbh->do($sqlstmt);
}

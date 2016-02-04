#!/usr/bin/perl
# ======================================================
# Writer   : Mico Cheng
# Version  : 20040910
# Use for  : remove IP from DenyIP
# ======================================================

use DBI;

$n = scalar(@ARGV);
die "ip2remove.pl list-file\n" until ($n eq 1);
$accessfile = shift;

$dbh = DBI->connect("DBI:mysql:mail_db;host=127.0.0.1", "rmail", "xxxxxxx") or die "$!\n";

open ACCESS, "$accessfile" or die "Can not open $accessfile:$!\n";
while (<ACCESS>) {
print "line: $_\n";
      if (/^(\d+\.\d+\.\d+\.\d+)$/) {
            #print "insert $remove_ip\n";
            &remove_DB($1);
      } elsif (/^(\d+\.\d+\.\d+)$/) {
            $trustcip = '$1.%';
            remove_DB($remove_ip);
      } elsif (/^(\d+\.\d+)/) {
            $trustbip = '$1.%';
            $trustcip = '$1.%';
      } else {
            print "no match RELAY:$_\n";
      }
}
$dbh->disconnect();
close(ACCESS);

sub remove_DB {
   $sqlstmt = sprintf("delete from DenyIP where s_ip like '%s')", $_[0]);
   $dbh->do($sqlstmt);
}

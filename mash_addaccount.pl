#!/usr/bin/perl
# ======================================================
# Writer   : Mico Cheng
# Version  : 20040910
# Use for  : transfer IP Class to DenyIP Table
# ======================================================

use DBI;

$account_list = "account.list";

$dbh = DBI->connect("DBI:mysql:mail_db;host=210.200.211.3", "rmail", "LykCR3t1") or die "$!\n";

open ACCOUNT, "$account_list" or die "Can not open $accessfile:$!\n";
while (<ACCOUNT>) {
    chmop;
    print "line: $_\n";
    insertaccount($_);
}
$dbh->disconnect();
close(ACCOUNT);

sub insertaccount {
  $s_mailid = $_[0];
  $s_mbox=sprintf("%s/%s/%s", substr($s_mailid, 0, 1), substr($s_mailid, 1, 1), $s_mailid);
  $sqlstmt = sprintf("insert into MailCheck values ('%s', '1', 'ms01','%s','0'", $s_mailid, $s_mbox);
  $sqlstmt = sprintf("insert into MailPass values ('%s', '1', ENCRYPT('abcdef'),'abcdef',NOW()", $s_mailid);
 $dbh->do($sqlstmt);
 system "mkdir -p /mnt/ms01/$s_mbox/Maildir/new";
 system "/usr/local/bin/chown -R rmail:rmail /mnt/ms01/$s_mbox");
}

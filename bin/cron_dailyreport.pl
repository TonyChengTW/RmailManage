#! /usr/local/bin/perl


use DBI;

require "/export/home/rmail/bin/config.pl";

$reporter='nekobe@watcher.com.tw,mikocheng@apol.com.tw';

$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
  || die_db($!);

$sqlstmt=sprintf("select count(*) from MailCheck");
$sth=$dbh->prepare($sqlstmt);
$sth->execute();

($active) = ($sth->fetchrow_array)[0];

$sqlstmt=sprintf("select count(*) from Suspend");
$sth=$dbh->prepare($sqlstmt);
$sth->execute();

($suspend) = ($sth->fetchrow_array)[0];

undef $sth;
$dbh->disconnect;

open(PROG, "|/usr/lib/sendmail -t");
print PROG "Date: ", `date`;
print PROG "From: ".$reporter."\n";
print PROG "To: ".$reporter."\n";
print PROG "Subject: Daily report\n\n";
print PROG "Active User: $active\n";
print PROG "Suspend User: $suspend\n\n\n";

close(PROG);

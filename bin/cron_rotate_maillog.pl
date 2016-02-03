#! /usr/local/bin/perl

use DBI;

require "/export/home/rmail/bin/config.pl";



$interval = 14400;

$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
$dbh=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
 || die_db($!);

$deadline = time()-$interval;
 
$sqlstmt=sprintf("SELECT * FROM MailLog WHERE UNIX_TIMESTAMP(s_time) < %d",
		$deadline);

$sth=$dbh->prepare($sqlstmt);
$sth->execute();

while (@data = $sth->fetchrow_array) {
	$sqlstmt=sprintf("insert into MailLog_Archive values ('%s', %d, '%s', '%s', '%s')",
			@data);
	$dbh->do($sqlstmt);
}

$sqlstmt=sprintf("DELETE FROM MailLog WHERE UNIX_TIMESTAMP(s_time) < %d",
		$deadline);
$dbh->do($sqlstmt);

$dbh->disconnect();

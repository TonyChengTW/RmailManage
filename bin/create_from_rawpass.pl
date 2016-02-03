#! /usr/local/bin/perl


use Time::HiRes qw(time);
use IO::Socket;

require "config.pl";

$|++;
die "./create_from_rawpass.pl <txt file> <domain_id> <ms>" if (scalar(@ARGV)!=3);
die "File ".$ARGV[0]." seem like doesn't exist!" if (!-e $ARGV[0]);

$g_start=time();
$cnt=0;
$file = $ARGV[0];
$domain_id = $ARGV[1];
$def_mhost= $ARGV[2];
$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
	|| die_db($!);
$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
$dbh_log=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
	|| die_db($!);
## Check if domain id is correct
$sqlstmt=sprintf("select * from DomainTransport where s_idx=%d", $domain_id);
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
if ($sth->rows!=1) {
	$dbh->disconnect();
	die "Domain id $domain_id doesn't exist!";
}

## Read from file and build account
open(FH, "<$file");
while (<FH>) {
	$s_start=time();
	chomp();
	($s_mailid, $s_rawpass)=split(/,/, $_);
	$s_mailid=lc($s_mailid);
	## Delete if exist!
	$sqlstmt=sprintf("delete from MailCheck where s_mailid='%s' and s_domain=%d",
			$s_mailid, $domain_id);
	$dbh->do($sqlstmt);
	$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
			$s_mailid, $domain_id);
	$dbh->do($sqlstmt);
	$sqlstmt=sprintf("delete from Suspend where s_mailid='%s' and s_domain=%d",
			$s_mailid, $domain_id);
	$dbh->do($sqlstmt);
	$sqlstmt=sprintf("delete from MailRecord_%s where s_mailid='%s' and s_domain=%d",
			substr($s_mailid, 0, 1),  $s_mailid, $domain_id);
	$dbh_log->do($sqlstmt);

	## Create new records
	$s_mbox=sprintf("%s/%s/%s", substr($s_mailid, 0, 1), substr($s_mailid, 1, 1),
			$s_mailid);
	$sqlstmt=sprintf("insert into MailCheck values ('%s', %d, '%s', '%s', 0)",
			$s_mailid, $domain_id, $def_mhost, $s_mbox);
	$dbh->do($sqlstmt);
	$sqlstmt=sprintf("insert into MailPass values ('%s', %d, ENCRYPT('%s'), '%s', NOW())",
			$s_mailid, $domain_id, $s_rawpass, $s_rawpass);
	$dbh->do($sqlstmt);
	$sqlstmt=sprintf("insert into MailRecord_%s values ('%s', %d, NOW(), NOW(), NOW(), '','','')",
			substr($s_mailid, 0, 1),  $s_mailid, $domain_id);
	$dbh_log->do($sqlstmt);

	## Create mdir

	

	
}
close(FH);
$dbh->disconnect();
$dbh_log->disconnect();
printf("\n\nCreated %d accounts, cost %f secs\n", $cnt, (time()-$g_start));

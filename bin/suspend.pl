#! /usr/local/bin/perl


use DBI;
use IO::Socket;

$|++;
die "./suspend.pl <domain_id> <soft_quota_by_day> <hart_quota_by_day>" if (scalar(@ARGV)!=3);



$domain_id = $ARGV[0];
$soft_quota = $ARGV[1] * 86400;
$hard_quota = $ARGV[2] * 86400;
@seed = ('a'..'z','0'..'9','_');

$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
	|| die_db($!);
$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
$dbh_log=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
	|| die_db($!);
## Get domain_id
$sqlstmt=sprintf("select * from DomainTransport where s_idx=%d", $domain_id);
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
if ($sth->rows!=1) {
  $dbh->disconnect();
  die "Domain id $domain_id doesn't exist!";
}

foreach $digit (@seed) {
	## Run all digits
	$sqlstmt=sprintf("select s_mailid, UNIX_TIMESTAMP(s_pop3time) from MailRecord_%s", $digit);
	$sth=$dbh_log->prepare($sqlstmt);
	$sth->execute();
	$sth->bind_col(1, \$s_mailid);
	$sth->bind_col(2, \$s_pop3time);
	while ($sth->fetch) {
		if (time() - $s_pop3time > $soft_quota) {
			if (time() - $s_pop3time > $hard_quota) {
				## Get old data
				$sqlstmt=sprintf("select * from MailCheck where s_mailid='%s' and s_domain=%d",
						$s_mailid, $domain_id);
				$sth2=$dbh->prepare($sqlstmt);
				$sth2->execute();
				($s_mailid, $s_domain, $s_mhost, $s_mbox, $s_status)=$sth2->fetchrow_array;
				undef($sth2);
				$sqlstmt=sprintf("select * from MailPass where s_mailid='%s' and s_domain=%d",
						$s_mailid, $domain_id);
				$sth2=$dbh->prepare($sqlstmt);
				$sth2->execute();
				($s_mailid, $s_domain, $s_encpass, $s_rawpass, $s_modifytime)=$sth2->fetchrow_array;
				undef($sth2);
				## Delete old data
				$sqlstmt=sprintf("delete from MailCheck where s_mailid='%s' and s_domain=%d",
						$s_mailid, $domain_id);
				$dbh->do($sqlstmt);
				$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
						$s_mailid, $domain_id);
				$dbh->do($sqlstmt);
				$sqlstmt=sprintf("delete from MailRecord_%s where s_mailid='%s' and s_domain=%d",
						substr($s_mailid, 0, 1), $s_mailid, $domain_id);
				$dbh_log->do($sqlstmt);

				## Backup to suspend
				$sqlstmt=sprintf("insert into Suspend values ('%s', %d, '%s', '%s', '%s', NOW())",
						$s_mailid, $domain_id, $s_rawpass, $s_mhost, $s_mbox);
				$dbh->do($sqlstmt);

				## Log it
			} else {
				## Send Warning....
				## TODO
				open(FH, ">>/tmp/warn.log");
				print FH $s_mailid, "\t", (time()-$s_pop3time), "\t", `date`;
				close(FH);
			}
		}
	}
}



undef($sth);
$dbh->disconnect();

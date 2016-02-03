#! /usr/local/bin/perl


use DBI;

require "/export/home/rmail/bin/config.pl";

open(FH, ">>/tmp/check.log");
$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
  || die_db($!);
$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
$dbh_log=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
  || die_db($!);

## MailCheck first
$sqlstmt="select s_mailid, s_domain FROM MailCheck";
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
while(($s_mailid, $s_domain)=($sth->fetchrow_array))  {
	$MailCheck{$s_mailid.'@@'.$s_domain}=1;
}

## MailPass
$sqlstmt="select s_mailid, s_domain FROM MailPass";
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
while (($s_mailid, $s_domain)=($sth->fetchrow_array)) {
	$MailPass{$s_mailid.'@@'.$s_domain}=1;
}

## Suspend
$sqlstmt="select s_mailid, s_domain FROM Suspend";
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
while (($s_mailid, $s_domain)=($sth->fetchrow_array)) {
	$Suspend{$s_mailid.'@@'.$s_domain}=1;
}

## 1.Check suspend but still MailCheck
foreach $tag (keys %Suspend) {
	($s_mailid, $s_domain) = split(/@@/, $tag);
	if ($MailCheck{$tag}==1) {
		## Unclean
		$sqlstmt=sprintf("select * from MailCheck where s_mailid='%s' and s_domain=%d",
				$s_mailid, $s_domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		@buf = $sth->fetchrow_array;
		print FH "CLEAN:SUSPENDED:MailCheck:".join(":", @buf)."\n";
		
	} else {
		## match
		next;
	}
}

## 2.Check MailCheck & MailPass
foreach $tag (keys %MailPass) {
	($s_mailid, $s_domain) = split(/@@/, $tag);
	if ($MailCheck{$tag}==1) {
		## Match
		next;
	} elsif ($Suspend{$tag}==1) {
		## Suspend but still live in MailPass, clean it
		$sqlstmt=sprintf("select * from MailPass where s_mailid='%s' and s_domain=%d",
				$s_mailid, $s_domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		@buf = $sth->fetchrow_array;
		print FH "CLEAN:SUSPENDED:MailPass:".join(":", @buf)."\n";
		$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
				$s_mailid, $s_domain);
		$dbh->do($sqlstmt);
		
	} else {
		## Unknown record, clean it
		$sqlstmt=sprintf("select * from MailPass where s_mailid='%s' and s_domain=%d",
				$s_mailid, $s_domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		@buf = $sth->fetchrow_array;
		print FH "CLEAN:NOMAILCHECK:MailPass:".join(":", @buf)."\n";
		$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
				$s_mailid, $s_domain);
		$dbh->do($sqlstmt);
	}
}


## 3.Check MailRecord for garbage record
foreach $digit (('a'..'z','0'..'9','_')) {
	$sqlstmt=sprintf("select s_mailid, s_domain from MailRecord_%s", $digit);
	$sth=$dbh_log->prepare($sqlstmt);
	$sth->execute();
	while (($s_mailid, $s_domain)=($sth->fetchrow_array)) {
		$tag=$s_mailid.'@@'.$s_domain;
		$MailRecord{$tag}=1;
		if ($MailCheck{$tag}!=1) {
			## garbage record, clean it
			$sqlstmt=sprintf("select * from MailRecord_%s where s_mailid='%s' and s_domain=%d",
					$digit, $s_mailid, $s_domain);
			$sth2=$dbh_log->prepare($sqlstmt);
			$sth2->execute();
			@buf=$sth2->fetchrow_array;
			print FH "CLEAN:NOMAILCHECK:MailRecord_$digit:".join(":", @buf)."\n";
			
			$sqlstmt=sprintf("delete from MailRecord_%s where s_mailid='%s' and s_domain=%d",
					$digit, $s_mailid, $s_domain);
			$dbh_log->do($sqlstmt);
		}
	}
}

## 4.Check MailRecord for lose record & MailPass for lose password
foreach $tag (keys %MailCheck) {
	($s_mailid, $s_domain) = split(/@@/, $tag);
	if ($MailRecord{$tag}!=1) {
		## Lose record
		$sqlstmt=sprintf("INSERT INTO MailRecord_%s values ('%s', %d, NOW(), NOW(), NOW(), '','','')",
				substr($s_mailid, 0, 1), $s_mailid, $s_domain);
		$dbh_log->do($sqlstmt);
		print FH "ADD:LOSERECORD:MailRecord_".substr($s_mailid, 0, 1).":$s_mailid:%d:NOW:NOW:NOW::::\n";
	}

	if ($MailPass{$tag}!=1) {
		print FH "WARN:LOSEPASS:MailPass:$s_mailid:$s_domain\n";
	}
}






undef $sth;
undef $sth2;
close(FH);

#!/usr/local/bin/perl
#-----------------------------------
#Writer : Mico Cheng
#Version: 20060213
#Host   : 210.200.211.3
#use for: SMTP User mass mail control
#----------------------------------
use DBI;
$db_host='210.200.211.3';
$db_user='rmail';
$db_passwd='xxxxxxx';

$dbh=DBI->connect("DBI:mysql:mail_db:$db_host", $db_user, $db_passwd) or die "can't connect $db_host:$!\n";

$sqlstmt='delete from DenyIP where s_reason like \'Limit%smtp%\'';
$sth=$dbh->prepare($sqlstmt);
$sth->execute() or die "Error:$!\n";

$sqlstmt='delete from DenyMailfrom where s_reason like \'Limit%smtp%\'';
$sth=$dbh->prepare($sqlstmt);
$sth->execute() or die "Error:$!\n";

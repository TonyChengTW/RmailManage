#!/usr/local/bin/perl
#-----------------------------------
#Writer : Mico Cheng
#Version: 20041231
#Host   : 210.200.211.3
#use for: Temp Blocking Remove (Gray-list)
#----------------------------------
use DBI;

$mail_file = shift || die "remove_list_from_deny.pl <mail list> <ip list>\n";
$ip_file = shift;

$dbh=DBI->connect('DBI:mysql:mail_db:210.200.211.3', 'rmail', 'LykCR3t1') or die "can't connect DB\n";

open MAIL ,"$mail_file" or die "can't open $mail_file:$!\n";
while (<MAIL>) {
    chomp;
    $sqlstmt=sprintf("delete from DenyMailfrom where s_mailfrom='%s'",$_);
    $sth=$dbh->prepare($sqlstmt);
    $sth->execute();

    $sqlstmt=sprintf("delete from DenyMailfrom where s_mailfrom=''");
    $sth=$dbh->prepare($sqlstmt);
    $sth->execute();
}

open IP ,"$ip_file" or die "can't open $ip_file:$!\n";
while (<IP>) {
    chomp;
    $sqlstmt=sprintf("delete from DenyIP where s_ip='%s'",$_);
    $sth=$dbh->prepare($sqlstmt);
    $sth->execute();
}

close LIST;

#! /usr/local/bin/perl


use DBI;
use Mail::POP3Client;
use Time::HiRes qw(time);

$|++;
die "./translate_pop3.pl <txt file> <domain_id> <pop3_host>" if (scalar(@ARGV)!=3);
die "File ".$ARGV[0]." seem like doesn't exist!" if (!-e $ARGV[0]);


$g_start=time();
$cnt=0;
$retr_size_total=0;
$retr_bulks_total=0;
$file = $ARGV[0];
$domain_id = $ARGV[1];
$pop3_host = $ARGV[2];

$dbh=DBI->connect("DBI:mysql:mail_db;host=210.200.211.3", "rmail", "xxxxxxx")
  || die_db($!);

$sqlstmt=sprintf("select * from DomainTransport where s_idx=%d", $domain_id);
$sth=$dbh->prepare($sqlstmt);
$sth->execute();
if ($sth->rows!=1) {
	  $dbh->disconnect();
		die "Domain id $domain_id doesn't exist!";
}
$s_basedir=($sth->fetchrow_array())[2];



open(FH, "<$file");
while (<FH>) {
	$s_start=time();
	$retr_size=0;
	$retr_bulks=0;
	chomp();
	($s_mailid, $s_rawpass)=split(/,/, $_);
	$s_mailid=lc($s_mailid);

	$sqlstmt=sprintf("select s_mhost, s_mbox from MailCheck where s_mailid='%s' and s_domain=%d",
			$s_mailid, $domain_id);
	$sth=$dbh->prepare($sqlstmt);
	$sth->execute();

	if ($sth->rows!=1) {
		next;
	}
	($s_mhost, $s_mbox)=$sth->fetchrow_array();
	
	$s_path=sprintf("%s/%s/%s/Maildir/new", $s_basedir, $s_mhost, $s_mbox);
	
	if (!-e $s_path) {
		next;
	}
	chdir($s_path);
	$pop = new Mail::POP3Client(
			USER		=>	$s_mailid,
			PASSWORD	=>	$s_rawpass,
			HOST		=>	$pop3_host)
		|| die "Cannot connect to $pop3_host: $@";

	for ($i=1; $i<=$pop->Count(); $i++) {
		$file_name=sprintf("%d.%05d%d.00000000.00.00.%s",
				time(), rand(10000), $i, $s_mhost);
		open(FILE, ">$file_name");
		foreach ($pop->HeadAndBody($i)) {
			print FILE $_, "\n";
			$retr_size+=length($_);
			$retr_size_total+=length($_);
		}
		close(FILE);

		$retr_bulks++;
		$retr_bulks_total++;
	}
	$pop->Close;

	printf("%s\t%sRetrieve %d bulks, %d bytes, cost %f secs\n",
			$s_mailid, (length($s_mailid)>7)? "":"\t", $retr_bulks, $retr_size, time()-$s_start);

	$cnt++;
}
close(FH);
undef $sth;
$dbh->disconnect;

printf("Total User: %d, Total Bulks: %d, Total Size: %d, Cost: %f\n",
		$cnt, $retr_bulks_total, $retr_size_total, time()-$g_start);
exit;

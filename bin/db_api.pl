#! /usr/local/bin/perl


use IO::Socket;
use DBI;
use Authen::Libwrap qw( hosts_ctl STRING_UNKNOWN);
use Net::FTP;

## auth flush
$|++;

require "/export/home/rmail/bin/config.pl";
$remote_ip=$ENV{'TCPREMOTEIP'};
$local_host= `hostname`; chomp($local_host);

if (!hosts_ctl("db_api", $local_host, $remote_ip)) {
	print STDOUT "-ERR 拒絕連線,Access denied\n";
	exit;
}

# main process


print STDOUT "+OK Welcome!\n";
$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
if ($buf eq 'adduser') {
	# Add user
	print STDOUT "+OK Give me id pass domain ms\n";
	$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
	($id, $pass, $domain, $ms) =split(/\s+/, $buf);
	if ($id && $pass && $domain) {
		# get domain id and check id is availiable
		$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
		$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
			|| die_db($!);
		$sqlstmt=sprintf("select s_idx from DomainTransport where s_domain='%s'", $domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STDOUT "-ERR 該網域不存在,no such domain\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($domain_id)=($sth->fetchrow_array)[0];
		# find ms's real hostnode
		$sqlstmt=sprintf("select s_nodename from HostMap where s_hostname='%s' AND s_domain=%d", $ms, $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STROUT "-ERR 該郵件主機不存在,no such ms\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($ms_node)=($sth->fetchrow_array)[0];
		# check id is availiable
		if (substr($id, 0, 1) eq '.' || substr($id, 1, 1) eq '.' || substr($id, 0, 1) eq '_' || substr($id, 0, 1) eq '!' || length($id)<2) {
			print STDOUT "-ERR 帳號格式錯誤,wrong id!\n";
			close(STDOUT);
			exit;
		}
		$sqlstmt=sprintf("select * from Suspend where s_mailid='%s' AND s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 0) {
			print STDOUT "-ERR 該帳號已被關閉,this id was suspended\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		$sqlstmt=sprintf("select * from MailCheck where s_mailid='%s' AND s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 0) {
			print STDOUT "-ERR 該帳號已有人申請,this id was existed\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		
		print STDOUT "+OK $id $pass $domain_id $ms_node\n";
		$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
		if ($buf eq 'go') {
			# do jobs
			# 1. add to mailcheck & mailpass
			$mbox=substr(lc($id), 0, 1)."/".substr(lc($id), 1, 1)."/".lc($id);
			$sqlstmt=sprintf("insert into MailCheck values ('%s', %d, '%s', '%s', 0)",
					lc($id), $domain_id, $ms, $mbox);
			$dbh->do($sqlstmt);
			$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' AND s_domain=%d",
					lc($id), $domain_id);
			$dbh->do($sqlstmt);
			$sqlstmt=sprintf("insert into MailPass values ('%s', %d, ENCRYPT('%s'), '%s', NOW())",
					lc($id), $domain_id, $pass, $pass);
			$dbh->do($sqlstmt);

			# 2. build mailbox
			# TODO: call ms api to build mbox
			$socket=IO::Socket::INET->new(
					PeerAddr		=>	$ms,
					PeerPort		=>	$API{'ms'}{'port'},
					Proto				=>	'tcp',
					Type				=>	SOCK_STREAM)
				|| die_socket($@);
			do {
				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
				($buf)=(split(/\s+/, $buf))[0];
			} while ($buf ne '+OK' && $buf ne '-ERR');

			if ($buf eq '-ERR') {
				print STDOUT "-ERR 連結伺服器失敗,socket error\n";
				close($socket);
				close(STDOUT);
				exit;
			}

			print $socket "createmdir\n";

			do {
				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
				($buf)=(split(/\s+/, $buf))[0];
			} while ($buf ne '+OK' && $buf ne '-ERR');

			if ($buf eq '-ERR') {
				print STDOUT "-ERR 使用者目錄早已被建立dir already exist\n";
				close($socket);
				close(STDOUT);
				exit;
			}

			$mpath=sprintf("/mnt/%s/%s", $ms, $mbox);
			print $socket "$mpath\n";

			do {
				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
				($buf)=(split(/\s+/, $buf))[0];
			} while ($buf ne '+OK' && $buf ne '-ERR');

			if ($buf eq '-ERR') {
				print STDOUT "-ERR 用戶目錄早已存在,dir already exist\n";
				close($socket);
				close(STDOUT);
				exit;
			}
			
			$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
			$dbh2=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
				|| die_db($!);
			$sqlstmt=sprintf("delete from MailRecord_%s where s_mailid='%s' and s_domain=%d",
					substr(lc($id), 0, 1), lc($id), $domain_id);
			$dbh2->do($sqlstmt);
			$sqlstmt=sprintf("insert into MailRecord_%s values ('%s', %d, NOW(), NOW(), NOW(), '','','')",
					substr(lc($id), 0, 1), lc($id), $domain_id);
			$dbh2->do($sqlstmt);
			$dbh2->disconnect();

			close($socket);
			print STDOUT "+OK 完成,Done!\n";
			open(FH, ">>/tmp/api.log");
			print FH "$id\tAdd\t".`date`;
			close(FH);

		} else {
			print STDOUT "-ERR API指令錯誤,Wrong command!\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}		
		close(STDOUT);
		exit;
		
	} else {
		print STDOUT "-ERR API參數格式有誤,Format error!\n";
		close(STDOUT);
		exit;
	}
} elsif ($buf eq 'deluser') {
	print STDOUT "+OK Give me id domain\n";
	$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
	($id, $domain)=split(/\s+/,$buf);
	
	if ($id && $domain) {
		$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
		$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
			|| die_db($!);
		$sqlstmt=sprintf("select s_idx from DomainTransport where s_domain='%s'", $domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STDOUT "-ERR no such domain\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($domain_id)=($sth->fetchrow_array)[0];

		$sqlstmt=sprintf("select s_mbox, s_mhost from MailCheck where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows !=1) {
			print STDOUT "-ERR no such user\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($s_mbox, $s_mhost)=($sth->fetchrow_array)[0,1];
		$s_path=sprintf("/mnt/%s/%s", $s_mhost, $s_mbox);

		## Do jobs
		# 1, delete all database record
		$sqlstmt=sprintf("delete from MailCheck where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$dbh->do($sqlstmt);

		$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$dbh->do($sqlstmt);
		# 2. delete mdir
		$socket=IO::Socket::INET->new(
				PeerAddr		=>	$s_mhost,
				PeerPort		=>	$API{'ms'}{'port'},
				Proto				=>	'tcp',
				Type				=>	SOCK_STREAM)
			|| die_socket($@);
		do {
			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
			($buf)=(split(/\s+/, $buf))[0];
		} while ($buf ne '+OK' && $buf ne '-ERR');

		if ($buf eq '-ERR') {
			print STDOUT "-ERR socket error\n";
			close($socket);
			close(STDOUT);
			exit;
		}

		print $socket "deletemdir\n";

		do {
			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
			($buf)=(split(/\s+/, $buf))[0];
		} while ($buf ne '+OK' && $buf ne '-ERR');

		if ($buf eq '-ERR') {
			print STDOUT "-ERR socket error\n";
			close($socket);
			close(STDOUT);
			exit;
		}

		print $socket "$s_path\n";

		do {
			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
			($buf)=(split(/\s+/, $buf))[0];
		} while ($buf ne '+OK' && $buf ne '-ERR');

		if ($buf eq '-ERR') {
			print STDOUT "-ERR socket error\n";
			close($socket);
			close(STDOUT);
			exit;
		}
		
		close($socket);
		print STDOUT "+OK Done!\n";
		open(FH, ">>/tmp/api.log");
		print FH "$id\tDelete\t".`date`;
		close(FH);
		
	} else {
		print STDOUT "-ERR Wrong format!\n";
		close(STDOUT);
		exit;
	}
	
} elsif ($buf eq 'sususer') {
	print STDOUT "+OK Give me id domain\n";
	$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
	($id, $domain)=split(/\s+/,$buf);
	
	if ($id && $domain) {
		$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
		$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
			|| die_db($!);
		$sqlstmt=sprintf("select s_idx from DomainTransport where s_domain='%s'", $domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STDOUT "-ERR no such domain\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($domain_id)=($sth->fetchrow_array)[0];

		$sqlstmt=sprintf("select * from MailCheck where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows !=1) {
			print STDOUT "-ERR no such user\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($s_mailid, $s_domain, $s_mhost, $s_mbox, $s_status) = $sth->fetchrow_array();
		$s_path=sprintf("/mnt/%s/%s", $s_mhost, $s_mbox);
		# get rawpass
		$sqlstmt=sprintf("select s_rawpass from MailPass where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows !=1) {
			print STDOUT "-ERR No password record?\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($s_rawpass)=($sth->fetchrow_array)[0];

		## Do jobs
		# 1, delete all database record
		$sqlstmt=sprintf("delete from MailCheck where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$dbh->do($sqlstmt);

		$sqlstmt=sprintf("delete from MailPass where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$dbh->do($sqlstmt);
		# 2. Record
		$sqlstmt=sprintf("insert into Suspend values ('%s', %d, '%s', '%s', '%s', NOW())",
				$s_mailid, $s_domain, $s_rawpass, $s_mhost, $s_mbox);
		$dbh->do($sqlstmt);
		# 3. delete mdir
#		$socket=IO::Socket::INET->new(
#				PeerAddr		=>	$s_mhost,
#				PeerPort		=>	$API{'ms'}{'port'},
#				Proto				=>	'tcp',
#				Type				=>	SOCK_STREAM)
#			|| die_socket($@);
#		do {
#			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#			($buf)=(split(/\s+/, $buf))[0];
#		} while ($buf ne '+OK' && $buf ne '-ERR');

#		if ($buf eq '-ERR') {
#			print STDOUT "-ERR socket error\n";
#			close($socket);
#			close(STDOUT);
#			exit;
#		}

#		print $socket "deletemdir\n";

#		do {
#			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#			($buf)=(split(/\s+/, $buf))[0];
#		} while ($buf ne '+OK' && $buf ne '-ERR');

#		if ($buf eq '-ERR') {
#			print STDOUT "-ERR socket error\n";
#			close($socket);
#			close(STDOUT);
#			exit;
#		}

#		print $socket "$s_path\n";

#		do {
#			$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#			($buf)=(split(/\s+/, $buf))[0];
#		} while ($buf ne '+OK' && $buf ne '-ERR');

#		if ($buf eq '-ERR') {
#			print STDOUT "-ERR socket error\n";
#			close($socket);
#			close(STDOUT);
#			exit;
#		}
#		
#		close($socket);

		print STDOUT "+OK Done!\n";
		close(STDOUT);
		exit;
		
	} else {
		print STDOUT "-ERR Wrong format!\n";
		close(STDOUT);
		exit;
	}
} elsif ($buf eq 'unsususer') {
	print STDOUT "+OK Give me id domain\n";
	$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
	($id, $domain)=split(/\s+/,$buf);
	
	if ($id && $domain) {
		$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
		$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
			|| die_db($!);
		$sqlstmt=sprintf("select s_idx from DomainTransport where s_domain='%s'", $domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STDOUT "-ERR no such domain\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($domain_id)=($sth->fetchrow_array)[0];

		$sqlstmt=sprintf("select s_mailid, s_domain, s_rawpass, s_mhost, s_mbox from Suspend where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows !=1) {
			print STDOUT "-ERR no such user\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($s_mailid, $s_domain, $s_rawpass, $s_mhost, $s_mbox)=$sth->fetchrow_array;

		$sqlstmt=sprintf("delete from Suspend where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$dbh->do($sqlstmt);
		
		## Do jobs
		# 1, insert back all database record
		$sqlstmt=sprintf("insert into MailCheck values ('%s', %d, '%s', '%s', 0)",
				lc($id), $domain_id, $s_mhost, $s_mbox);
		$dbh->do($sqlstmt);

		$sqlstmt=sprintf("insert into MailPass values ('%s', %d, ENCRYPT('%s'), '%s', NOW())",
				lc($id), $domain_id, $s_rawpass, $s_rawpass);
		$dbh->do($sqlstmt);
		# 2. create mdir
#			$socket=IO::Socket::INET->new(
#					PeerAddr		=>	$s_mhost,
#					PeerPort		=>	$API{'ms'}{'port'},
#					Proto				=>	'tcp',
#					Type				=>	SOCK_STREAM)
#				|| die_socket($@);
#			do {
#				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#				($buf)=(split(/\s+/, $buf))[0];
#			} while ($buf ne '+OK' && $buf ne '-ERR');

#			if ($buf eq '-ERR') {
#				print STDOUT "-ERR socket error\n";
#				close($socket);
#				close(STDOUT);
#				exit;
#			}

#			print $socket "createmdir\n";
#
#			do {
#				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#				($buf)=(split(/\s+/, $buf))[0];
#			} while ($buf ne '+OK' && $buf ne '-ERR');
#
#			if ($buf eq '-ERR') {
#				print STDOUT "-ERR socket error\n";
#				close($socket);
#				close(STDOUT);
#				exit;
#			}
#
#			$mpath=sprintf("/mnt/%s/%s", $s_mhost, $s_mbox);
#			print $socket "$mpath\n";
#
#			do {
#				$buf=<$socket>; chomp($buf); $buf=~s /\r//g;
#				($buf)=(split(/\s+/, $buf))[0];
#			} while ($buf ne '+OK' && $buf ne '-ERR');
#
#			if ($buf eq '-ERR') {
#				print STDOUT "-ERR socket error\n";
#				close($socket);
#				close(STDOUT);
#				exit;
#			}
			
			$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'rec'}{'name'}, $DB{'rec'}{'host'});
			$dbh2=DBI->connect($dsn, $DB{'rec'}{'user'}, $DB{'rec'}{'pass'})
				|| die_db($!);
			$sqlstmt=sprintf("delete from MailRecord_%s where s_mailid='%s' and s_domain=%d",
					substr(lc($id), 0, 1), lc($id), $domain_id);
			$dbh2->do($sqlstmt);
			$sqlstmt=sprintf("insert into MailRecord_%s values ('%s', %d, NOW(), NOW(), NOW(), '','','')",
					substr(lc($id), 0, 1), lc($id), $domain_id);
			$dbh2->do($sqlstmt);
			$dbh2->disconnect();

#			close($socket);
			print STDOUT "+OK Done!\n";
			close(STDOUT);
			exit;	
	} else {
		print STDOUT "-ERR Wrong format!\n";
		close(STDOUT);
		exit;
	}
} elsif ($buf eq 'changepass') {
	print STDOUT "+OK Tell me <id> <domain> <new_password>\n";
	$buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
	($id, $domain, $pass)=split(/\s+/, $buf);
	if ($id && $domain) {
		$dsn=sprintf("DBI:mysql:%s;host=%s", $DB{'mta'}{'name'}, $DB{'mta'}{'host'});
		$dbh=DBI->connect($dsn, $DB{'mta'}{'user'}, $DB{'mta'}{'pass'})
			|| die_db($!);
		$sqlstmt=sprintf("select s_idx from DomainTransport where s_domain='%s'", $domain);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows != 1) {
			print STDOUT "-ERR no such domain\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}
		($domain_id)=($sth->fetchrow_array)[0];

		$sqlstmt=sprintf("select * from MailPass where s_mailid='%s' and s_domain=%d",
				lc($id), $domain_id);
		$sth=$dbh->prepare($sqlstmt);
		$sth->execute();
		if ($sth->rows !=1) {
			print STDOUT "-ERR no such user\n";
			$dbh->disconnect;
			close(STDOUT);
			exit;
		}

		$sqlstmt=sprintf("update MailPass set s_rawpass='%s', s_encpass=ENCRYPT('%s') where s_mailid='%s' and s_domain=%d",
				$pass, $pass, $id, $domain_id);
		$dbh->do($sqlstmt);
		$dbh->disconnect();
		print STDOUT "+OK done!\n";
		close(STDOUT);
	} else {
		print STDOUT "-ERR format error!\n";
		close(STDOUT);
		exit;
	}

} else {
	print STDOUT "-ERR Wrong Command: $buf!\n";
	close(STDOUT);
	exit;
}




sub die_db {
	$msg=$_[0];
	print STDOUT "-ERR Cannot connect to database: $msg\n";
	close(STDOUT);
	exit;
}

sub die_socket {
	$msg=$_[0];
	print STDOUT "-ERR Cannot connect to api socket: $msg\n";
	close(STDOUT);
	exit;
}

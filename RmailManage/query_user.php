<?php
	require "config.php";

	$s_mailid=trim($HTTP_POST_VARS['s_mailid']);
	$s_domain=trim($HTTP_POST_VARS['s_domain']);

	$dbh=mysql_connect($DB['mta']['host'], $DB['mta']['user'], $DB['mta']['pass']);
	mysql_select_db($DB['mta']['name'], $dbh);

	// get domain_id first
	$sqlstmt=sprintf("select s_idx, s_basedir from DomainTransport where s_domain='%s'", strtolower($s_domain));
	$sth=mysql_query($sqlstmt);
	$obj=mysql_fetch_object($sth); $domain_id=$obj->s_idx; $s_basedir=$obj->s_basedir;

	// get all data from mta
	$sqlstmt=sprintf("select * from MailCheck where s_mailid='%s' and s_domain=%d",
			strtolower($s_mailid), $domain_id);
	$sth=mysql_query($sqlstmt);
	if (mysql_num_rows($sth)!=1) {

		$sqlstmt=sprintf("select *, UNIX_TIMESTAMP(s_suspend_time) as s_suspendtime from Suspend where s_mailid='%s' and s_domain=%d",
				strtolower($s_mailid), $domain_id);
		$sth=mysql_query($sqlstmt);
		if (mysql_num_rows($sth)!=1) {
			echo "No such user!\n";
			exit;
		}
		$obj=mysql_fetch_object($sth);

			printf("<h3>User had been suspended!</h3>");
			printf("<h4>Suspend on %s</h3>", date("Y:m:d H:i:s", $obj->s_suspendtime));
			printf("<table border=1>");
			printf("<tr><td>ID</td><td>Mail Host</td><td>Mailbox</td><td>Raw-Password</td></tr>");
			printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
					$obj->s_mailid, $obj->s_mhost, $obj->s_mbox, $obj->s_rawpass );
			printf("</table>");


		exit;
		
	}

	
	$mta=mysql_fetch_object($sth);
	mysql_close($dbh);

	// password
	$dbh=mysql_connect($DB['pwd']['host'], $DB['pwd']['user'], $DB['pwd']['pass']);
	mysql_select_db($DB['pwd']['name'], $dbh);
	$sqlstmt=sprintf("select * from MailPass where s_mailid='%s' and s_domain=%d",
			strtolower($s_mailid), $domain_id);
	$sth=mysql_query($sqlstmt);
	$pwd=mysql_fetch_object($sth);
	mysql_close($dbh);
		
	// log
	$dbh=mysql_connect($DB['log']['host'], $DB['log']['user'], $DB['log']['pass']);
	mysql_select_db($DB['log']['name'], $dbh);
	$sqlstmt=sprintf("select s_smtpip, s_pop3ip, s_wwwip, UNIX_TIMESTAMP(s_smtptime) as s_smtptime, UNIX_TIMESTAMP(s_pop3time) as s_pop3time, UNIX_TIMESTAMP(s_wwwtime) as s_wwwtime from MailRecord_%s where s_mailid='%s' and s_domain=%d",
			substr(strtolower($s_mailid), 0, 1), strtolower($s_mailid), $domain_id);
	$sth=mysql_query($sqlstmt);
	$log=mysql_fetch_object($sth);

	$sqlstmt=sprintf("select s_type, s_ip, UNIX_TIMESTAMP(s_time) as s_time from MailLog where s_mailid='%s' and s_domain=%d",
			strtolower($s_mailid), $domain_id);
	$sth=mysql_query($sqlstmt);

	// get quota
	$sock=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
	if ($sock < 0) {
	  echo "socket_create() failed: reason: " . socket_strerror ($sock) . "\n";
	}

  $result=socket_connect($sock, $mta->s_mhost, 8888);
	if ($result < 0) {
	  echo "socket_connect() failed.\nReason: ($result) " . socket_strerror($result) . "\n";
	}

  $buf=socket_read($sock, 2048);

	$cmd="getquota\n";
  socket_write($sock, $cmd, strlen($cmd));
  $buf=socket_read($sock, 2048);
	$cmd=sprintf("%s/%s/%s\n", $s_basedir, $mta->s_mhost, $mta->s_mbox);
  socket_write($sock, $cmd, strlen($cmd));
	$buf=socket_read($sock, 2048);
	$quota=substr($buf, 4, strlen($buf)-4);
	$buf=socket_read($sock, 2048);
	socket_close($sock);
	




printf("<h3>Basic Data</h3>");
	
printf("<table border=1>");
printf("<tr><td>ID</td><td>Mail Host</td><td>Mailbox</td><td>Raw-Password</td><td>Enc-Password</td><td>Quota</td></tr>");
printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
	$mta->s_mailid, $mta->s_mhost, $mta->s_mbox, $pwd->s_rawpass, $pwd->s_encpass, $quota);
printf("</table>");

printf("<h3>Last Access</h3>");
printf("<table border=1");
printf("<tr><td>Last SMTP IP</td><td>Last POP3 IP</td><td>Last WWW IP</td></tr>");
printf("<tr><td>%s.</td><td>%s.</td><td>%s.</td></tr>", $log->s_smtpip, $log->s_pop3ip, $log->s_wwwip);
printf("<tr><td>Last SMTP Time</td><td>Last POP3 Time</td><td>Last WWW Time</td><tr>");
printf("<tr><td>%s</td><td>%s</td><td>%s</td></tr>", date("Y:m:d H:i:s", $log->s_smtptime), date("Y:m:d H:i:s", $log->s_pop3time), date("Y:m:d H:i:s", $log->s_wwwtime));
printf("</table>");

	printf("<h3>Access History</h3>");
	printf("<table border=1 width=60%%>");
	printf("<tr><td>Type</td><td>Time</td><td>IP</td></tr>");
	while ($obj=mysql_fetch_object($sth)) {
		printf("<tr><td>%s</td><td>%s</td><td>%s</td></tr>", $obj->s_type, date("Y:m:d H:i:s", $obj->s_time), $obj->s_ip);
	}
	printf("</table>");
	mysql_close($dbh);
?>

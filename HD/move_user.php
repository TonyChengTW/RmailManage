<?php
	require "config.php";

	$s_mailid=trim($HTTP_POST_VARS['s_mailid']);
	$s_domain=trim($HTTP_POST_VARS['s_domain']);
	$s_mhost=trim($HTTP_POST_VARS['s_mhost']);

	$dbh=mysql_connect($DB['mta']['host'], $DB['mta']['user'], $DB['mta']['pass']);
	mysql_select_db($DB['mta']['name'], $dbh);
	// get domain_id first;
	$sqlstmt=sprintf("select s_idx, s_basedir from DomainTransport where s_domain='%s'", strtolower($s_domain));
	$sth=mysql_query($sqlstmt);
	$obj=mysql_fetch_object($sth); $domain_id=$obj->s_idx; $s_basedir=$obj->s_basedir;

	// get old mhost, mbox
	$sqlstmt=sprintf("select s_mhost, s_mbox from MailCheck where s_mailid='%s' and s_domain=%d", strtolower($s_mailid), $domain_id);
	$sth=mysql_query($sqlstmt);
	if (mysql_num_rows($sth)!=1) {
		echo "No such user!\n";
		mysql_close($dbh);
		exit;
	}
	$obj=mysql_fetch_object($sth); $o_mhost=$obj->s_mhost; $o_mbox=$obj->s_mbox;
	$o_path=sprintf("%s/%s/%s", $s_basedir, $o_mhost, $o_mbox);
	// querify if same host move
	$sqlstmt=sprintf("select s_nodename from HostMap where s_hostname='%s'", $s_mhost);
	$sth=mysql_query($sqlstmt);
	$obj=mysql_fetch_object($sth);
	if ($o_mhost == $obj->s_nodename) {
		echo "Same host, stop!\n";
		mysql_close($dbh);
		exit;
	}

	// connect to old host and pack
	$sock=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
	if ($sock < 0) {
		echo "socket_create() failed: reason: " . socket_strerror ($sock) . "\n";
	}

	$result=socket_connect($sock, $o_mhost, 8888);
	if ($result < 0) {
		echo "socket_connect() failed.\nReason: ($result) " . socket_strerror($result) . "\n";
	}

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="packuser\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="$o_path\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));
		
	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";
	socket_close($sock);

	// connect to new host and unpack
	$n_path=sprintf("%s/%s/%s", $s_basedir, $s_mhost, $o_mbox);
	$sock=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
	if ($sock < 0) {
	  echo "socket_create() failed: reason: " . socket_strerror ($sock) . "\n";
	}

  $result=socket_connect($sock, $s_mhost, 8888);
	if ($result < 0) {
	  echo "socket_connect() failed.\nReason: ($result) " . socket_strerror($result) . "\n";
	}

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="unpackuser\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";
	
	$cmd=sprintf("%s %s %s\n", $s_mailid, $o_mhost, $n_path);
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";
	socket_close($sock);

	// delete mdir
	$sock=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
	if ($sock < 0) {
	  echo "socket_create() failed: reason: " . socket_strerror ($sock) . "\n";
	}

	$result=socket_connect($sock, $o_mhost, 8888);
	if ($result < 0) {
		echo "socket_connect() failed.\nReason: ($result) " . socket_strerror($result) . "\n";
	}

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="deletemdir\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="$o_path\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";
  socket_close($sock);

	// change MailCheck
	$sqlstmt=sprintf("update MailCheck set s_mhost='%s' where s_mailid='%s' and s_domain=%d",
			$s_mhost, $s_mailid, $domain_id);
	$sth=mysql_query($sqlstmt);
	mysql_close($dbh);

	
	
?>
Finish!

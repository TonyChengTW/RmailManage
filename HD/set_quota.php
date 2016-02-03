<?php
	require "config.php";

	$s_mailid=trim($HTTP_POST_VARS['s_mailid']);
	$s_domain=trim($HTTP_POST_VARS['s_domain']);
	$s_quota=trim($HTTP_POST_VARS['s_quota']);


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
  $obj=mysql_fetch_object($sth); $s_mhost=$obj->s_mhost; $s_mbox=$obj->s_mbox;
	$s_path=sprintf("%s/%s/%s", $s_basedir, $s_mhost, $s_mbox);

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

	$cmd="setquota\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd=sprintf("%s %s \n", $s_path, $s_quota);
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	socket_close($sock);
?>
Finish!

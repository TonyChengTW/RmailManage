<?php
	require "config.php";

	$s_mailid=trim($HTTP_POST_VARS['s_mailid']);
	$s_domain=trim($HTTP_POST_VARS['s_domain']);
	$s_rawpass=trim($HTTP_POST_VARS['s_rawpass']);

	$sock=socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
	if ($sock < 0) {
		echo "socket_create() failed: reason: " . socket_strerror ($sock) . "\n";
	}


	$result=socket_connect($sock, '210.200.211.3', 9999);
	if ($result < 0) {
		echo "socket_connect() failed.\nReason: ($result) " . socket_strerror($result) . "\n";
	}


	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd="changepass\n";
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";

	$cmd=sprintf("%s %s %s\n", $s_mailid, $s_domain, $s_rawpass);
	echo "Sending $cmd<br>\n";
	socket_write($sock, $cmd, strlen($cmd));

	$buf=socket_read($sock, 2048);
	echo $buf, "<br>\n";
	socket_close($sock);
?>
Finish!

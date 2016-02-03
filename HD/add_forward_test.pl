#! /usr/local/bin/perl
#  ----------------------------------
#   Writer  : Mico Cheng 
#   Version : 2004091501
#   Use for : 
#             1. for HD to add forward E-Mail
#   Host : x
#  ----------------------------------
use IO::Socket qw(:DEFAULT :crlf);
$/ = CRLF;

$old_account = $ARGV[0];
$old_domain = $ARGV[1];
$new_mail = $ARGV[2];

$old_mail = "$old_account"."\@"."$old_domain";

## ----------------    ethome all server's IP and port ---
$sock_ethome_ip = '210.58.94.70';
$sock_cm1_ip = '210.58.94.22';
$sock_hc_ip = '210.58.94.31';
$sock_port = '7879';

die "./ethome_transfer_setting.pl old_account old_domain new_mail\n" if (scalar(@ARGV)!=3);

# Forwarding E-Mail by HD Rmail Web Page
&addforwarding($old_mail, $new_mail);

#--------------  subrotine --------
sub addforwarding {
    my($old_mail, $new_mail) = @_;
    ($old_account,$forwarding_host)= ($old_mail =~ /^(.*)@(\w+)\..*?$/);

    if ($forwarding_host eq 'ethome') {
        $sock_ip = $sock_ethome_ip;
    } elsif ($forwarding_host eq 'hc') {
        $sock_ip = $sock_hc_ip;
    } elsif ($forwarding_host eq 'cm1') {
        $sock_ip = $sock_cm1_ip;
    }

    $sock_target=IO::Socket::INET->new(PeerAddr        => $sock_ip,
                                       PeerPort        => $sock_port,
                                       Type            => SOCK_STREAM,
                                       Proto           => 'tcp')
        	 or die "can't open socket : $!\n";

    $sock_target->autoflush(1);
    
    $buf=<$sock_target>;chomp($buf); $buf=~s/\r//g;
    print "buf-establish=$buf\n";
    if (!$buf =~ /\+OK/) {
         print STDOUT "Error: establish fail:$buf\n";
         next;
    } else {
         print $sock_target "addforward",CRLF;
    }
    $buf=<$sock_target>;chomp($buf);
    print "response_add_buf=$buf\n";
    if ($buf =~ /\+OK/) {
        print $sock_target "$old_account $new_mail",CRLF;
        $buf=<$sock_target>;chomp($buf);
        if ($buf =~ /\+OK/) {
             print $sock_target "quit",CRLF;
             print STDOUT "Info: $old_mail->$new_mail forwarding OK!",CRLF;
        } else {
             print $sock_target CRLF;
             print $sock_target "quit",CRLF;
             print STDOUT "Error: $buf  - $old_mail->$new_mail",CRLF; 
        }
    } else {
        print $sock_target "quit",CRLF;
             print STDOUT "Error: $buf",CRLF;
    }
    close($sock_target);
}

#! /usr/local/bin/perl


use Authen::Libwrap qw( hosts_ctl STRING_UNKNOWN);
use IO::Socket;
use Net::FTP;
use DBI;
$|++;

require "/export/home/rmail/bin/config.pl";

$port=$API{'ms'}{'port'};
$max_client=10;
$remote_ip=$ENV{'TCPREMOTEIP'};
$local_host= `hostname`; chomp($local_host);

  if (!hosts_ctl("ms_api", $local_host, $remote_ip)) {
    print STDOUT "Access deny!\n";
    exit;
  }

  print STDOUT "+OK Welcome!\n";
  $buf=<STDIN>; chomp($buf); $buf=~s /\r//g;

  if ($buf eq 'createmdir') {
    print STDOUT "+OK Give me path to create!\n";
    $buf=<STDIN>;chomp($buf); $buf=~s /\r//g;
    $path=$buf;
    $path=~s /\r//g;
    if (-e $path) {
      print STDOUT "-ERR Path exist!\n";
    } else {
  #    mkdir("$path");
      system("mkdir -p $path");
      mkdir("$path/Maildir");
      mkdir("$path/Maildir/new");
      chown 5000, 5000, "$path";
      chown 5000, 5000, "$path/Maildir";
      chown 5000, 5000, "$path/Maildir/new";
      print STDOUT "+OK Done!\n";
    }
    exit;
  } elsif ($buf eq 'deletemdir') {
    print STDOUT "+OK Give me path to delete!\n";
    $buf=<STDIN>;chomp($buf); $buf=~s /\r//g;
    $path=$buf;
    $path=~s /\r//g;
    if (-e $path) {
      system("/bin/rm -rf $path");
      if (!-e $path) {
        print STDOUT "+OK Done!\n";
      } else {
        print STDOUT "-ERR Delete fail!\n";
      }
    } else {
      print STDOUT "-ERR no such dir!\n";
    }
    exit;
  } elsif ($buf eq 'setquota') {
    print STDOUT "+OK Give me path and quota!\n";
    $buf=<STDIN>;chomp($buf); $buf=~s /\r//g;
    ($path, $quota)=split(/\s+/, $buf);
    if (!-e $path) {
      print STDOUT "-ERR Path not exist!\n";
      exit;
    }
    open(FH, ">$path/.quota");
    print FH "$quota";
    print STDOUT "+OK Done!\n";
    exit;
  } elsif ($buf eq 'getquota') {
    print STDOUT "+OK Give me path!\n";
    $buf=<STDIN>;chomp($buf); $buf=~s /\r//g;
    $path=$buf;
    if (!-e $path) {
      print STDOUT "-ERR no such path!\n";
      exit;
    }
    if (!-e "$path/.quota") {
      print STDOUT "+OK 0\n";
      exit;

    } else {
      open(FH, "<$path/.quota");
      $quota=<FH>; chomp($quota);
      close(FH);
      print STDOUT "+OK $quota\n";
      exit;
    }
  
  } elsif ($buf eq 'packuser') {
    print STDOUT "+OK Give me path!\n";
    $buf=<STDIN>;chomp($buf); $buf=~s /\r//g;
    $path=$buf;
    if (!-e $path) {
      print STDOUT "-ERR No such path!\n";
      exit;
    }
    @dmy=split(/\//, $path);
    $id=$dmy[scalar(@dmy)-1];
    $dmy[scalar(@dmy)-1]='';
    $prefix=join('/', @dmy);
    chdir($prefix);
    system("/usr/local/bin/tar -zcspf /tmp/$id.tar.gz $id");
  
    if (-e "/tmp/$id.tar.gz") {
      print STDOUT "+OK Pack done!\n";
    } else {
      print STDOUT "-ERR Pack fail!\n";
    }
    exit;
  
  } elsif ($buf eq 'unpackuser') {
    print STDOUT "+OK Give me id old-ms new-path!\n";
    $buf=<STDIN>; chomp($buf); $buf=~s /\r//g;
    chdir("/tmp/");
    ($id, $ms, $path)=split(/\s+/,$buf);
    $ftp=Net::FTP->new("$ms", Debug => 0)
      || die_socket($@);
    $ftp->login($FTP{'user'}, $FTP{'pass'});
    $ftp->cwd("/tmp/");
    $ftp->binary;
    $ftp->get("$id.tar.gz")
      || die_socket($ftp->message);
    $ftp->quit;
    if (!-e "/tmp/$id.tar.gz") {
      print STDOUT "-ERR No packed file!\n";
      exit;
    }
    @dmy=split(/\//, $path);
    $dmy[scalar(@dmy)-1]='';
    $prefix=join('/', @dmy);
		system("mkdir -p $prefix") if (!-e $prefix);
    chdir($prefix);
    system("/usr/local/bin/tar -zxspf /tmp/$id.tar.gz");
    if (-e $path) {
      print STDOUT "+OK Done!\n";
    } else {
      print STDOUT "-ERR Fail!\n";
    }
    exit;
  } else {
    print STDOUT "-ERR Wrong Command!\n";
  }
  
  
  
  
  




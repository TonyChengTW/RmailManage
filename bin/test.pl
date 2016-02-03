#!/usr/local/bin/perl
$a = 'no such domain';
until ($a =~ 'domain')) {
   print "\$a not eq domain\n";
} else {
   print "\$a eq domain\n";
}

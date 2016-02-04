#!/usr/local/bin/perl
#---------------------------------
#Writer : Mico Cheng
#Version: 20050613
#Use for: show sleep time beond n second
#Host   : MySQL system
#---------------------------------
$sleep_time = shift || 100;

print "sleep time = $sleep_time\n";
$line_number = 0;
@process = `/usr/local/etc/mysql/bin/mysqladmin -u rmail -pxxxxxxx processlist`;
print "ID\tHost\t\tCommand\tTime\n";

foreach (@process) {
   $line_number++;
   chomp;
   next if ($line_number < 3);
   ($id,$host,$command,$time) = (split /\s+/)[1,5,9,11];
   print "$id\t$host\t$command\t$time\n" if ($time > $sleep_time);
}

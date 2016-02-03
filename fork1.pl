#!/usr/local/bin/perl
$child_pid = fork();
die "fork failed!  $!\n" until defined($child_pid);
if ($child_pid > 0) {
    print "I'm Parent ,my pid=$$\t Child pid=$child_pid\n";
} else {
    $parent_pid = getppid;
    print "I'm Child ,my pid=$$\tParent pid=$parent_pid\n";
}

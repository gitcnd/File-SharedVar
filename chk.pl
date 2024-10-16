use strict;
use warnings;
use lib 'lib';

# Standalone test program

$|=1;

use File::SharedVar;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $shared_var=File::SharedVar->new(file => '/tmp/test_file_sharedvar.dat', create => 1); # create new
ok(1,"new ok") if($shared_var);

$shared_var->update('caller', "I am $$", 0);
ok($shared_var->read('caller') eq "I am $$","stored OK");

$shared_var->update('foo', 1, 1);
ok($shared_var->read('foo') == 1,"inc OK");

$shared_var->update('foo', -1, 1);
ok(!$shared_var->read('foo') ,"dec OK");

my $nforks=4;
my $nreps=4;

my @child_pids;

foreach (1 .. $nforks) {
  #sleep(1);
  my $pid = fork();
  diag("$pid is proc #$_") if($pid);
  die "Cannot fork: $!" unless defined $pid;

  if ($pid == 0) {
    # Child process
    my $s2=File::SharedVar->new(file => '/tmp/test_file_sharedvar.dat');
    for (1 .. $nreps) {
      $s2->update('foo', 1, 1); # Increment 'foo' by 1
      diag("$$ inc #$_");
    }
    diag("$$ over #$_");
    exit(0);
  } else {
    # Parent process
    push @child_pids, $pid;
  }
}

# Parent process waits for all children to terminate
my $kid;
while (($kid = wait()) != -1) {
    print "Parent: Child with PID $kid terminated\n";
}



# Parent process waits for all child processes to exit
#foreach my $pid (@child_pids) {
#  diag("$$ waiting on $pid. foo=",$shared_var->read('foo'));
#  waitpid($pid, 0);
#}

# Test that the value of 'foo' equals $nforks * $nreps
my $expected = $nforks * $nreps;
my $actual   = $shared_var->read('foo');

ok($actual == $expected, "foo equals $expected after children have incremented");




diag( "\n\nHI\n\n" );

done_testing();

=for later


my $first = 0;
my $ntest = 4;

# Update variables
$shared_var->update('last', "I am $$", 0);
$shared_var->update("me $$", $shared_var->read('foo'), 0);

for my $i (1..$ntest) {
  my $value = $shared_var->read('foo') // 0;
  $first = 1 if $value == 0;
  $shared_var->update('foo', 1, 1);  # Increment 'foo' by 1
}

for my $i (1..$ntest) {
  $shared_var->update('foo', -1, 1);  # Decrement 'foo' by 1
}

sleep(2);  # Allow other processes to run concurrently

# Print final value of 'foo'
print "$$ Final value of foo: " . ($shared_var->read('foo') // 0) . "\n";

if ($first) {
  sleep(10);
  print "\e[32;1m$$ Last before ending: foo=" . ($shared_var->read('foo') // 0) . "\e[0m\n";
}

=cut


sub ok {
}
sub diag {
  print @_; print "\n";
}

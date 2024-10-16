package File::SharedVar;

=head1 NAME

File::SharedVar - Pure-Perl extension to share variables between Perl processes using files and file locking for their transport

=head1 SYNOPSIS

  use File::SharedVar;

  # Create a new shared variable object
  my $shared_var = File::SharedVar->new(
    file   => '/tmp/ramdisk/sharedvar.dat',
    create => 1,  # Set to 1 to create or truncate the file
  );

  # Update a key
  my $new_value = $shared_var->update('foo', 1, 1); # Increment 'foo' by 1

  # Read a key
  my $value = $shared_var->read('foo');
  print "Value of foo: $value\n";


=head1 DESCRIPTION

File::SharedVar provides an object-oriented interface to share variables between Perl processes using a file as shared storage, with working cross-platform file locking mechanisms to ensure data integrity in concurrent environments.

It allows you to read, update, and reset shared variables stored in a file (uses JSON format), making it easy to coordinate between multiple processes.

This module uses a lockfile as a mutex, because flock() does not work properly in WSL1, WSL2, or their lxfs file systems (randomly throws "invalid argument" on seek() calls under heavy load).

This module was written to serve as a functioning alternative to the incomplete and unmaintained "IPC::Shareable" module which has multiple unfixed bugs reported against it (and which shreds your shared memory under long-running processes)

=head2 CAUTION

This module relies on your filesystem properly supporting file locking (and your selection of a lockfile on that filesystem), which is not the case for Windows Services for Linux (WSL1 and WSL2) nor their "lxfs" filesystem.

The "test" phase of installing this module, when run on a system with broken locking, may take an extended amount of time to fail (many minutes or even hours).

=cut

use 5.030000;
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock LOCK_EX LOCK_UN LOCK_NB O_RDWR O_EXCL O_CREAT);
#use Fcntl ':flock';   # For using O_EXCL and O_CREAT constants
#use Fcntl qw(:DEFAULT :flock O_EXCL O_CREAT O_RDWR); # Ensure proper constants are imported

#my($LOCK_EX,$LOCK_UN,$LOCK_NB,$O_RDWR)=(2,8,4,2); # These are required, because the $LOCK_* constants are sometimes not numbers, and inconveniently require "no strict 'subs';"
my($LOCK_EX,$LOCK_UN,$LOCK_NB,$O_RDWR,$O_EXCL,$O_CREAT)=(0+LOCK_EX,0+LOCK_UN,0+LOCK_NB,0+O_RDWR,0+O_EXCL,0+O_CREAT); # Avoid no strict 'subs' and nonnumber issues

our $VERSION = '1.00';

eval {
  require JSON::XS;
  JSON::XS->import; 1;
} or do {
  require JSON;
  JSON->import;
};

#my $json_text = encode_json($data);
#my $decoded_data = decode_json($json_text);


=head1 METHODS

=head2 new

  my $shared_var = File::SharedVar->new(%options);

Creates a new `File::SharedVar` object.

=over 4

=item *

C<file>: Path to the shared variable file. Defaults to C</tmp/sharedvar.dat>.

=item *

C<create>: If true (non-zero), the file will be created if it doesn't exist or truncated if it does. Defaults to C<0>.

=back

=cut

sub new {
  my ($class, %args) = @_;
  my $self = {
    file   => $args{file}   // '/tmp/sharedvar.dat',
  };

  bless $self, $class;

  if ($args{create}) {
    # Create or truncate the file
    open my $fh, '>', $self->{file} or die "Cannot open $self->{file}: $!";
    close $fh;
  } elsif (!-f $self->{file}) {
    die $self->{file},": No such file";
  }
  return $self;
}

=head2 read

  my $value = $shared_var->read($key);

Reads the value associated with the given key from the shared variable file.

=over 4

=item *

C<$key>: The key whose value you want to read.

=back

Returns the value associated with the key, or C<undef> if the key does not exist.

=cut

sub read {
  my ($self, $key) = @_;
  my($data,$fh)= _load_from_file($self->{file});
  return $data->{$key};
}

=head2 update

  my $new_value = $shared_var->update($key, $value, $increment);

Updates the value associated with the given key in the shared variable file.

=over 4

=item *

C<$key>: The key to update.

=item *

C<$value>: The value to set or increment by.

=item *

C<$increment>: If true (non-zero), increments the existing value by C<$value>; otherwise, sets the key to C<$value>.

=back

Returns the new value associated with the key after the update.

=cut

sub update {
  my ($self, $key, $val, $inc) = @_;
  my($data,$fh)= _load_from_file($self->{file},1);

  # Update the value for the key
  if ($inc) {
    $data->{$key} = ($data->{$key} // 0) + $val;
  } else {
    $data->{$key} = $val;
  }
  my $ret = $data->{$key};
  _save_to_file($self->{file},$data,$fh);

  return $ret;
}



sub _load_from_file {
    my($lock_share_file,$staylocked)=@_;

    #sysopen(my $lfh, $lock_share_file.'.lock', O_EXCL | O_CREAT ) or die "Cannot open $lock_share_file.lock: $!";

#O_EXCL + O_CREAT

    #open my $fh, '+<', $lock_share_file or die "$$ Cannot open $lock_share_file: $!";
    sysopen(my $fh, $lock_share_file, $O_RDWR) or die "Cannot open $lock_share_file: $!";

    my $data = {};

    print "$$ pre-lock\n";
    flock($fh, $LOCK_EX) or die "$$ Cannot lock: $!";
    print "$$ post-lock\n";
    #my $json_text = do { local $/; <$fh> };
    my $json_text;
    sysread($fh,$json_text,65535); # = do { local $/; <$fh> };
    seek($fh, 0, 0) or die "$$ Cannot seek: $!";
    $data = decode_json($json_text) if $json_text;
    unless($staylocked){  # LOCK_UN (unlock)
      flock($fh, $LOCK_UN) or die "$$ Cannot unlock: $!";
      $fh->close; $fh=undef;
    }
    return($data,$fh);
}

sub _save_to_file {
    my ($lock_share_file,$data,$fh) = @_;
    #flock($fh, $LOCK_EX) or die "$$ Cannot lock: $!";  # LOCK_EX (exclusive lock for writing)
    truncate($fh, 0) or die "$$ Cannot truncate $lock_share_file file: $!";
    #print $fh encode_json($data);
    syswrite($fh,encode_json($data));
    flock($fh, $LOCK_UN) or die "$$ Cannot unlock: $!";  # LOCK_UN (unlock)
    $fh->close; $fh=undef; 
}

sub _open_lock {
  my($lock_share_file)=@_;
  my $i=0;
  while($i++<9999) {
    sysopen(my $fh, $lock_share_file, $O_RDWR) or die "Cannot open $lock_share_file: $!";
    
  }
}









1; # End of File::SharedVar

__END__

=head1 EXPORT

None by default.

=head1 SOURCE / BUG REPORTS

Please report any bugs or feature requests on the GitHub repository at:

L<https://github.com/gitcnd/File-SharedVar>

=head1 AUTHOR

This module was written by Chris Drake E<lt>cdrake@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2024 Chris Drake. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.30.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

# perl -MPod::Markdown -e 'Pod::Markdown->new->filter(@ARGV)' lib/File/SharedVar.pm  > README.md

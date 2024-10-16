# NAME

File::SharedVar - Pure-Perl extension to share variables between Perl processes using files and file locking for their transport

# CAUTION

This github release is not currently functional (I've just discovered that WSL and lxfs have bugs in their file locking, and this code is a work-in-progress to try and accomodate those platforms)

# SYNOPSIS

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

# DESCRIPTION

File::SharedVar provides an object-oriented interface to share variables between Perl processes using a file as shared storage, with proper file locking mechanisms to ensure data integrity in concurrent environments.

It allows you to read, update, and reset shared variables stored in a file (uses JSON format), making it easy to coordinate between multiple processes.

# METHODS

## new

    my $shared_var = File::SharedVar->new(%options);

Creates a new \`File::SharedVar\` object.

- `file`: Path to the shared variable file. Defaults to `/tmp/sharedvar.dat`.
- `create`: If true (non-zero), the file will be created if it doesn't exist or truncated if it does. Defaults to `0`.

## read

    my $value = $shared_var->read($key);

Reads the value associated with the given key from the shared variable file.

- `$key`: The key whose value you want to read.

Returns the value associated with the key, or `undef` if the key does not exist.

## update

    my $new_value = $shared_var->update($key, $value, $increment);

Updates the value associated with the given key in the shared variable file.

- `$key`: The key to update.
- `$value`: The value to set or increment by.
- `$increment`: If true (non-zero), increments the existing value by `$value`; otherwise, sets the key to `$value`.

Returns the new value associated with the key after the update.

# EXPORT

None by default.

# SOURCE / BUG REPORTS

Please report any bugs or feature requests on the GitHub repository at:

[https://github.com/gitcnd/Math-LiveStats](https://github.com/gitcnd/Math-LiveStats)

# AUTHOR

This module was written by Chris Drake <cdrake@cpan.org>.

# COPYRIGHT AND LICENSE

Copyright (c) 2024 Chris Drake. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.30.0 or,
at your option, any later version of Perl 5 you may have available.

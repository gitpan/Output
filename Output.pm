package Test::Output;
use strict;
use IO::File;
use File::Recurse;
use File::stat;
use Cwd;
use Shell qw(diff);
use vars qw($VERSION);

$VERSION="1.02";

sub new {
    my ($class, $dir) = @_;
    $dir = getcwd()."/$dir" if $dir !~ m,^/,;
    if (!-d $dir) {
	mkdir($dir,0777) or die "mkdir $dir";
    }
    my $o = bless { dir => $dir }, $class;

    $o->{stdout} = new IO::File;
    open($o->{stdout}, ">&STDOUT");
    open(STDOUT, ">$dir/out") or die "open $dir/out: $!";
    select STDOUT;
    $o->check("$dir/out");

    my $log = "$dir/diffs";
    $o->{'logname'} = $log;
    $o->{'log'} = new IO::File;
    $o->{'log'}->open($log, ">") or die "open $log: $!";

    $o;
}

sub check {
    my ($o, $file) = @_;
    push(@{$o->{'check'}}, $file);
}

sub ready {
    my ($o) = @_;
    close(STDOUT);
    select $o->{stdout};

    my $accept = new IO::File;
    $accept->open(">$o->{dir}/accept") or die "open $o->{dir}/accept: $!";
    $accept->print("#!/bin/sh\n");

    my (@ok,@bad);

    for my $orig (@{$o->{'check'}}) {
	my $old = $orig;
	$old =~ s|^.*?([^/]+)$|$1|;
	my $new = "$o->{dir}/$old.new";
	$old = "$o->{dir}/$old.good";
	system("cp $orig $new");
	if (!-e $old) { system("cp $new $old"); }
	my $diff = diff('-c', $old, $new);
	if ($diff !~ /^No differences encountered/) {
	    my $oldfh = select $o->{'log'};
	    print $diff;
	    select $oldfh;
	    print $accept "cp $new $old\n";
	    push(@bad, $orig);
	} else {
	    unlink($new);
	    push(@ok, $orig);
	}
    }
    $accept->close;
    chmod(0777, "$o->{dir}/accept")==1 or die "chmod accept: $!";
    (\@ok,\@bad);
}

sub go {
    my ($o, $ok, $bad) = @_;
    if (@_ == 1) { ($ok, $bad) = $o->ready(); }
    print "RESULTS:\n";
    for (@$ok) { print "ok $_\n"; }
    for (@$bad) { print "!! $_\n"; }
}

sub harness_report {
    my ($d, $start) = @_;
    $start ||= 1;

    my %result;
    my ($ok,$bad) = $d->ready();
    my $allok=1;
    for (@$ok) { $result{$_}=1 }
    for (@$bad) { $result{$_}=0; $allok=0; }
    
    print "1..".scalar(@$ok + @$bad)."\n" if $start == 1;
    
    my $t=$start;
    for my $f (sort keys %result) {
	my $ok = $result{$f};
	print($ok? "ok $t\n" : "not ok $t\n");
	warn "!! $f\n" if !$ok;
	++ $t;
    }
    
    warn "-> $d->{dir}/diffs\n" if !$allok;
}

1;
__END__

=head1 NAME

Test::Output -  make it easier to do regression testing on logs or files

=head1 SYNOPSIS

    my $diff = new Test::Output("../regret/mytest");

    $diff->check("log.011");
    $diff->check("log.012");

    $diff->harness_report(1);

=head1 DESCRIPTION

Runs a context diff on a set of files with the expectation that
these files will not change.

=over 4

=item #

Create a new Test::Output object C<$TEST>.  Pass the directory C<$DIR>
that you will use to save all the log files in question.  STDOUT is
redirected to C<$DIR/out>.

=item #

Execute the code you want to test.  Pass any files you want to check to
the C<check('file')> method.

=item #

When you are done with your code, call $TEST->harness_report(1).  All
the files you mentioned will be compared with files generated during
the prior run.  Context diffs will be sent to C<$DIR/diffs>.  File
statuses will be written to standard output:

  1..5
  ok 1
  ok 2
  ok 3
  not ok 4
  !! /tmp/risk3  (stderr)
  ok 5
  -> /tmp/diffs  (stderr)

C<ok> indicates that there were no differences.  You can examine the
differences in the files marked with C<!!> in the C<$DIR/diffs>
file.

If you decide to accept the new versions, you may source the
C<$DIR/accept> shell script.  This script will copy the new versions
into $DIR.  These new files will be used for future comparisons.

=back

The key to using this package successfully is to compare deltas
instead the logs themselves.  So you might create a C<before.log>,
C<after.log> and then check the C<diff> between them.  Context diffing
non-context diffs produces some interesting result files!

=head1 BUGS

There are no test scripts.  (Ack!)

=head1 AUTHOR

Copyright (c) 1997 Joshua Nathaniel Pritikin.  All rights reserved.
This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

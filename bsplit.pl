#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':utf8';
use open ':std';

my $max_bytes = 32000000;
if ($#ARGV >= 0) {
  $max_bytes = 1000000 * $ARGV[0];
}
my $seqno = 0;
my $path = sprintf("x_%03d.sql", $seqno);
my $out;
open($out, '>', $path);
my $bytes = 0;
while (my $line = <STDIN>) {
  my $len = length($line);
  if ($bytes + $len >= $max_bytes) {
    close($out);
    $bytes = 0;
    $seqno++;
    $path = sprintf("x_%03d.sql", $seqno);
    open($out, '>', $path);
  }
  print $out $line;
  $bytes += $len;
}
close($out);
__END__

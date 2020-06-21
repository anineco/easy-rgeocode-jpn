#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':utf8';
use open ':std';

my $seqno = 0;
my $path = sprintf("x_%03d.sql", $seqno);
my $out;
open($out, '>', $path);
my $bytes = 0;
while (my $line = <STDIN>) {
  my $len = length($line);
  if ($bytes + $len >= 32000000) { # 32M
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

#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':utf8';
use open ':std';
use File::Slurper 'read_text';
use JSON;

foreach my $filename (@ARGV) {
  my $text = read_text($filename);
  my $data = from_json($text);
  foreach my $feature (@{$data->{features}}) {
    my $code = $feature->{properties}->{N03_007} || 0; # 行政区域コード（null: 所属未定地）
    print q/SET @area='{"type":"Polygon","coordinates":/, to_json($feature->{geometry}->{coordinates}), q/}';/;
    print q/INSERT INTO `gyosei` VALUES (/, 0 + $code , q/,ST_GeomFromGeoJSON(@area,1));/, "\n";
  }
}
__END__

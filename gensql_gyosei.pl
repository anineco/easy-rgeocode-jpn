#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':utf8';
use open ':std';
use JSON;

while (my $json_text = <STDIN>) {
  next if ($json_text !~ /"Feature"/);
  chomp($json_text);
  chop($json_text) if ($json_text =~ /,$/);
  my $data = from_json($json_text); # croaks on error
  my $code = $data->{properties}->{N03_007} || 0; # 行政区域コード（null: 所属未定地）
  print q/SET @area='{"type":"Polygon","coordinates":/, to_json($data->{geometry}->{coordinates}), q/}';/;
  print q/INSERT INTO `gyosei` VALUES (/, 0 + $code , q/,ST_GeomFromGeoJSON(@area,1));/, "\n";
}
__END__

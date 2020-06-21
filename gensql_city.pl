#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':utf8';
use open ':std';
use URI;
use Web::Scraper;

my $codes = scraper {
  process 'table tr', 'codes[]' => scraper {
    process 'td:nth-child(1)', 'code' => 'TEXT';
    process 'td:nth-child(2)', 'name' => 'TEXT';
  };
};

my $uri = URI->new('https://nlftp.mlit.go.jp/ksj/gml/codelist/AdminAreaCd.html');
my $res = $codes->scrape($uri);
$res->{codes}->[0] = { 'code' => 0, name => 'unknown' };
for my $code (@{$res->{codes}}) {
  print 'INSERT INTO `city` VALUES (', 0 + $code->{code}, q{,'}, $code->{name}, q{');}, "\n";
}
__END__

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
my @codes = @{$codes->scrape($uri)->{codes}};
shift(@codes);
for my $code (@codes) {
  print q{INSERT INTO `city` VALUES (}, 0 + $code->{code}, q{,'}, $code->{name}, q{');}, "\n";
}
#
print <<EOS, "\n";
INSERT INTO `city` VALUES (0,'所属未定地');
INSERT INTO `city` VALUES (3216,'岩手県滝沢市');
INSERT INTO `city` VALUES (4216,'宮城県富谷市');
INSERT INTO `city` VALUES (11246,'埼玉県白岡市');
INSERT INTO `city` VALUES (12239,'千葉県大網白里市');
INSERT INTO `city` VALUES (40231,'福岡県那珂川市');
UPDATE `city` SET name='兵庫県丹波篠山市' WHERE code=28221;
EOS
__END__

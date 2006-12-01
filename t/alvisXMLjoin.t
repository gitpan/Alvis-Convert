#!/usr/bin/perl
use Test::More qw(no_plan);

my $outdir = 't/test-data/out';
mkdir $outdir unless (-d $outdir);

my $res = `perl bin/alvisXMLjoin.pl t/test-data/original/0/*alvis* | grep -c "<documentRecord"`;
chomp $res;
ok($res == 2);

`rm -rf $outdir`;
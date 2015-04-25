#!/usr/bin/env perl

use strict;
use warnings;

use lib '/storage/perlwork/mojowork/server/site1/lib/Site1/';
use Inputchk;

use feature 'say';


my $str = 'aaa@bbb.ccc';
my $email = Inputchk->new($str);
my $res = $email->string;
   say "$res";

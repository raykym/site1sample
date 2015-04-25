#!/usr/bin/env perl

# TEST用mysqld起動を確認する

use strict;
use warnings;
use feature 'say';

use lib '/storage/perlwork/mojowork/server/site1/lib';
use lib '/storage/perlwork/mojowork/server/site1/t';

use Site1mysqld;

# testDB start モジュールからDBを呼び出す前に起動する
my $mysqld = Site1mysqld::load;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Site1');

#say $ENV{TEST_DSN};

subtest 'signup' => sub {
    $t->post_ok('/signupact' => form => { email => 'aaa@bbb',username => 'test user', password => 'aaa1_pass' })->status_is(302);
};

sleep (100);

#更新をチェック
subtest '/menu' => sub {
    $t->get_ok('/menu')->status_is(302);
};

done_testing;

    my $dbh = DBI->connect($ENV{TEST_DSN});

    my $sth = $dbh->prepare("select * from user_tbl");
       $sth->execute;
    my $sth2 = $dbh->prepare("select * from signup_tbl");
       $sth2->execute;

    my $res = $sth->fetchall_arrayref();
    my $res2 = $sth2->fetchall_arrayref();

    foreach my $i (@{$res}){
        say @{$i};
    }
    foreach my $j (@{$res2}){
        say @{$j};
    }



# cleanup
undef $mysqld;

system('rm -rf /storage/tmp_work/etc');
system('rm -rf /storage/tmp_work/tmp');
system('rm -rf /storage/tmp_work/var');




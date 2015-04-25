package Site1mysqld;

# Site1用sitedataテーブル群をtestデータベースに作成したDBの起動

use strict;
use warnings;
use feature 'say';

use DBI;
use Test::mysqld;
use Test::More;
use Config::PL;

use Data::Dumper;

sub load {

# site1dbconf.plを読み出し
my $config = config_do 'site1dbconf.pl';
my %conf = config_do 'site1dbconf.pl';

my $mysqld = Test::mysqld->new(
    my_cnf => {
      'innodb_file_per_table' => '1',
      'skip-networking' => '', # no TCP socket
      },
    base_dir => '/storage/tmp_work',
  ##  #copy_data_from => '/storage/tmp_work/tmp_data/mysql'
    ) or plan skip_all => $Test::mysqld::errstr;
   
   $ENV{TEST_DSN} = $mysqld->dsn;
#   say $mysqld->dsn;

   my $dbh = DBI->connect(
           $mysqld->dsn(),
        );

# makedbconf.plからテーブルをクリエイト
foreach my $j (keys %conf){
    foreach my $k ( keys $conf{$j} ){
       my $sql = $conf{$j}{$k};
       my $sth_make_sitedata = $dbh->prepare($sql);
          $sth_make_sitedata->execute;
    }
}

# テーブルが作成されたのか確認
#   my $sth = $dbh->prepare("show tables;");
#      $sth->execute;
#
#   my $res = $sth->fetchall_arrayref();
#      foreach my $i (@{$res}) {
#          print "@{$i}\n";
#          };

#     print Dumper($res); 

 return $mysqld;

}

1;

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;
use Encode;
use DBI;

use lib '/storage/perlwork/mojowork/server/site1/t';
use Site1mysqld;

my $mysqld = Site1mysqld::load;  #newではなくloadでインスタンスを作る。

#open (OUT,'> objdumper.txt');
#open (OUT2,'> objdumper2.txt');

my $dbh = DBI->connect($ENV{TEST_DSN});

my $t = Test::Mojo->new('Site1');

subtest 'get /' => sub {
    $t->get_ok('/')->status_is(200)->text_is('h1' => 'ThisSite');
};

subtest 'post /signupact' => sub {
    # 処理後リダイレクトされるので、text_likeのようなものは処理されない。
    $t->post_ok('/signupact' => form => { email => 'aaa@bbb', username => 'test1user', password => 'aaa1_pass'})->status_is(302);
};

   #ブラウザ側の動きの代わりにDBからsidを取り直す
   my $getsid = 'SELECT sessionid FROM signup_tbl where email = ?';
   my $sth_getsid = $dbh->prepare($getsid);
      $sth_getsid->execute('aaa@bbb');
   my $res = $sth_getsid->fetchrow_arrayref();
   my $sid = @{$res};

subtest 'get /menu' => sub {

   my $ua = $t->ua;
      $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
          name => 'site1',
          value => "$sid",
          domain => 'westwind.iobb.net',
          path => '/'
         )
      );

   my $word = 'ようこそ';
      $word = encode_utf8($word);
    $t->get_ok('/menu')->status_is(302);   ####->text_is('h3' => $word);

#   print (OUT2 Dumper $t);

};

subtest 'get /menu/upload' => sub {
   my $ua = $t->ua;
      $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
          name => 'site1',
          value => "$sid",
          domain => 'westwind.iobb.net',
          path => '/'
         )
      );
    $t->get_ok('/menu/upload')->status_is(302);

    # templateが選択されないのでダンプする
#    print (OUT Dumper $t);

};


###########

#subtest 'url path' => sub {
   # $t->get_ok('/signup')->status_is(200)->content_like(qr/Mojolicious/i);
 
#    my $param = {  email => 'aaa@bbb', username => 'rrrrrrrr', password => 'aaapass' };
#    $t->post_ok('/menu/signupact' => {Accept => '*/*'} => form => $param)->status_is(404);


#    print (OUT2 Dumper $t);
#};

#subtest 'check template' => sub {
#    my $c = $t->app->build_controller;
#    ####ok $c->render('Top#mainmenu'), 'rendering';
#    ok $c->render(controller => 'Top', template => 'top', format => 'html', handler => 'ep'), 'rendering';
#    print (OUT Dumper $c);
#};

done_testing();

undef $mysqld;

# cleanup
    system('rm -rf /storage/tmp_work/etc');
    system('rm -rf /storage/tmp_work/tmp');
    system('rm -rf /storage/tmp_work/var');


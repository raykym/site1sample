package Site1;
use Mojo::Base 'Mojolicious';
#use DBI;
use DBIx::Connector;

sub startup {
  my $self = shift;
  # hypnotoad start
  $self->config(hypnotoad=>{listen => ['http://192.168.0.8:3800'],workers => 4});

# DB設定 $self->app->dbconn->dbh でアクセス可能になる

  # TEST環境用DSN
  if ( defined $ENV{TEST_DSN} ){
    (ref $self)->attr(
       dbconn => sub {
            DBIx::Connector->new($ENV{TEST_DSN});
        })
    } else {
  # 実環境ではこちらのDSN設定
  my   $config = $self->plugin('Config');
  (ref $self)->attr(
       dbconn => sub {
           DBIx::Connector->new("dbi:mysql:dbname=sitedata;host=$config->{dbhost};port=3306","$config->{dbname}","$config->{dbpass}",
        {RaiseError=>1, AutoCommit=>1,mysql_enable_utf8=>1});
       }
      );
  } # else

##  my $sth = $self->app->dbh->prepare("$config->{sql1}");
##     $sth->execute();

  # Router
  my $r = $self->routes;

### bridge設定
  my $bridge = $r->under->to('Login#usercheck'); 
# listviewを付加したもの。
  my $listbridge = $bridge->under->to('Filestore#listview');

# websocket setting
########  $r->websocket('/menu/chatroom/echo')->to(controller => 'Chatroom', action => 'echo');
  $bridge->websocket('/menu/chatroom/echo')->to(controller => 'Chatroom', action => 'echo');
  $bridge->websocket('/menu/chatroom/echodb')->to(controller => 'Chatroom', action => 'echodb');
  $bridge->websocket('/menu/chatroom/echopg')->to(controller => 'Chatroom', action => 'echopg');
  $r->websocket('/signaling')->to(controller => 'Chatroom', action => 'signaling');

  # Normal route to controller
#   $r->get('/example')->to('example#welcome');
  $r->any('/')->to('top#top');
  $r->get('/signup')->to('login#signup');        
  $r->get('/signin')->to('login#signin');       
  $r->post('/signinact')->to('login#signinact'); #template未使用
  $r->post('/signupact')->to('login#signupact'); #template未使用 


   # 以下はログイン認証済でないとページに入れない
  $bridge->get('/menu')->to('top#mainmenu');          
  $bridge->get('/menu/settings')->to('login#menusettings');
  $bridge->get('/menu/settings/email')->to('login#emailset');
  $bridge->post('/menu/settings/emailact')->to('login#emailsetact'); #template未使用
  $bridge->get('/menu/settings/uname')->to('login#unameset');
  $bridge->post('/menu/settings/unameact')->to('login#unamesetact'); #template未使用
  $bridge->get('/menu/settings/passwd')->to('login#passwdset');
  $bridge->post('/menu/settings/passwdact')->to('login#passwdsetact'); #template未使用
  $listbridge->any('/menu/settings/seticon')->to('filestore#seticon');
  $bridge->any('/menu/settings/seticonact')->to('filestore#seticonact');

#  $r->get('/menu/upload')->to('filestore#upload');

  $bridge->route('/menu/upload')->to('filestore#upload');
  $bridge->post('/menu/uploadact')->to('filestore#uploadact');

## listbridgeへ移行  $bridge->get('/menu/listview')->to('filestore#listview');
# list処理をbridgeに噛ませたもの
# filelist => \@slice, page => $pageを受ける
  $listbridge->get('/menu/listview')->to('filestore#listview_p');

  $bridge->any('/menu/fileview')->to('filestore#fileview'); # 個別表示ページ
  $bridge->post('/menu/fileviewact')->to('filestore#fileviewact'); # コメントの入力

  $bridge->any('/imgload')->to('filestore#imgload'); # imgload用パス
  $bridge->any('/imgcomm')->to('filestore#imgcomm'); # chatroom用パス

  $listbridge->any('/menu/delfileview')->to('filestore#delfileview');
  $bridge->post('/menu/delfileviewact')->to('filestore#delfileviewact');

  $bridge->get('/menu/chatroom')->to('chatroom#view');
  $bridge->get('/menu/chatroomdb')->to('chatroom#viewdb');
  $bridge->get('/menu/chatroompg')->to('chatroom#viewpg');
  $bridge->get('/menu/mirror')->to('mirror#mirror');

  $r->any('*')->to('Top#unknown'); # 未定義のパスは全てtop画面へ
}

1;

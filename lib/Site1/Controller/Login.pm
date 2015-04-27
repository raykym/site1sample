package Site1::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';
use Encode;
use Date::Format;
use MIME::Base64::URLSafe; # icon用oidを渡す
use MongoDB;

# 独自パスを指定して自前モジュールを利用
use lib '/storage/perlwork/mojowork/server/site1/lib/Site1';
use Sessionid;
use Inputchk;

# This action will render a template
sub signup {
  my $self = shift;
  #表示のみで入力結果を/signupactで処理する
  $self->render(msg => '');
}
sub signin {
  my $self = shift;
  #表示のみで入力結果を/signupactで処理する
  $self->render(msg => '');
}
sub signupact {
  my $self = shift;

  my $config = $self->app->plugin('Config');

  # DB設定
  my $sth_signup = $self->app->dbconn->dbh->prepare("$config->{sql_signup}");
  my $sth_user = $self->app->dbconn->dbh->prepare("$config->{sql_user}");
  my $sth_chk_signup = $self->app->dbconn->dbh->prepare("$config->{sql_chk_signup}");

  #signupから入力パラメータを受け取る。
  #入力チェックと重複チェックを行い、表示ページを振り分ける

  my $email = $self->param('email');
     $email = encode_utf8($email);
  my $username = $self->param('username');
     $username = encode_utf8($username);
  my $password = $self->param('password');
     $password = encode_utf8($password);

# 入力チェック
  my $chkemail = Inputchk->new($email);
     $chkemail->email;
  my $res_e = $chkemail->result;
     undef $chkemail;
     if ($res_e > 0 ) { 
          $self->app->log->debug('Notice: email check error.');
         }

     # 登録済みチェック
     if ( $res_e == 0 ) { 
         $sth_chk_signup->execute($email);
         if ( $sth_chk_signup->rows != 0 ) { $res_e = 1; }
                   # $res_eを１にしてエラーにする
         if ($res_e > 0 ) { 
              $self->app->log->debug('Notice: email DB check error.');
              }
          }

  my $chkuname = Inputchk->new($username);
     $chkuname->ngword;
  my $res_un = $chkuname->result;
     undef $chkuname;
     if ( $res_un > 0 ) {
         $self->app->log->debug('Notice: username check error.');
        }

  my $chkpass = Inputchk->new($password);
     $chkpass->password;
  my $res_pa = $chkpass->result;
     undef $chkpass;
     if ( $res_pa > 0 ) { 
        $self->app->log->debug('Notice: password check error.');
       }

  # 入力エラーの場合の表示遷移
  if ($res_e != 0 or $res_un != 0 or $res_pa != 0) {
     $self->app->log->debug('Notice: Input Error');
     $self->render(msg => '--- input error ---', template => 'login/signup');
     return;
   } # error 入力ページへ戻る

   # UTF-8デコード
     $email = decode_utf8($email);
     $username = decode_utf8($username);
     $password = decode_utf8($password);


  my $sid = Sessionid->new->sid;
  my $uid = Sessionid->new($email)->uid;
     # user情報の登録
     $sth_user->execute($email,$username,$password,$uid);
     $sth_signup->execute($email,$sid);


# cookie設定
     $self->cookie('site1'=>"$sid",{httponly => 'true',path => '/', max_age => '31536000', secure => 'true'});

  $self->redirect_to('/menu'); #/menuへリダイレクト

# 利用した変数の解放
  undef $sid;
  undef $email;
  undef $username;
  undef $password;
  undef $sth_signup;
  undef $sth_user;
  undef $sth_chk_signup;
}

sub usercheck {
    my $self = shift;
    # 認証が必要な場合すべてこのパスを通過する

       $self->app->log->debug('Notice: Usercheck ON!');

    # DB接続
    my $config = $self->app->plugin('Config');
    my $sth_sid_chk = $self->app->dbconn->dbh->prepare("$config->{sql_sid_chk}");
    my $sth_user_chk = $self->app->dbconn->dbh->prepare("$config->{sql_user_chk}");
    my $sth_chktimeupdate = $self->app->dbconn->dbh->prepare("$config->{sql_chktime_update}");

    #mongoDBでロギング　pubsubに利用予定->うまく行かなかった
    my $mongoclient = MongoDB::MongoClient->new(host => 'localhost', port => '27017');
    my $accessdb = $mongoclient->get_database('accessdb');
    my $sessionlog = $accessdb->get_collection('sessionlog');


    my $sid = $self->cookie('site1');

    # cookieが取れない->リダイレクト
    if ( ! defined $sid ){ 
        $self->app->log->debug('Notice: Not get Cookie!');
        $self->redirect_to('/');
        return;
      }

    # sidからチェック開始
       $sth_sid_chk->execute($sid);
    my $get_email = $sth_sid_chk->fetchrow_hashref();
    my $email = $get_email->{email};
       $sth_user_chk->execute($email);
    my $get_uname = $sth_user_chk->fetchrow_hashref();
    my $username = $get_uname->{username};
    my $uid = $get_uname->{uid};
    my $icon = $get_uname->{icon};
    # $iconが空ならNow printingが設定される。
       if (! defined $icon ) { $icon = 'rKzHfJwYJkApps4uk7cjAQ';}
       $icon = urlsafe_b64encode($icon); #urlsafe_b64encode

    # email,usernameが取得できない場合 ->リダイレクト
    if ( ! defined $email and ! defined $username ) {
        $self->app->log->debug('Notice: email or username not get Error!');
        $self->redirect_to('/');
        return;
       }

    #日付update 無意味なupdateでtimestampをupdate
    my $dumytime = time;
    $sth_chktimeupdate->execute($dumytime,$sid);
  ###  $self->app->log->debug("DEBUG: DBI: $DBI::errstr ");

#    my $requrl = $self->req->url->to_abs;
# URLが取れなくて断念
    #mongodbへの記録
#    $sessionlog->insert({ sid => $sid,
#                          uid => $uid,
#                          epoctime => $dumytime,
#                          url => $requrl
#                       });

    $self->stash( email => $email );
    $self->stash( username => $username );
    $self->stash( uid => $uid ); #uidはページで利用しないのでencodeしない
    $self->stash( icon => $icon );

  # 変数の解放
  undef $config;
  undef $sth_sid_chk;
  undef $sth_user_chk;
  undef $sid;
  undef $sth_chktimeupdate;
  undef $icon;

  # underのため、stashに設定して次へ
  return 1;
}

sub signinact {
    my $self = shift;

    # DB設定
    my $config = $self->app->plugin('Config');
    my $sth_signin_chk = $self->app->dbconn->dbh->prepare("$config->{sql_signin_chk}");
    my $sth_signup_update = $self->app->dbconn->dbh->prepare("$config->{sql_signup_update}");
    
    my $email = $self->param('email');
       $email = encode_utf8($email);
    my $password = $self->param('password');
       $password = encode_utf8($password);

    # 入力されたセットがあるのか確認
      $sth_signin_chk->execute($email,$password);
    my $signin_chk_uname =  $sth_signin_chk->fetchrow_hashref();
    my $username = $signin_chk_uname->{username};

       # usernameが取得できなければエラーとして入力ページヘ
       if ( ! defined $username ) {
           $self->app->log->debug('Notice: Not get username!');
           $self->render(msg => '--- e-mail or password Not match! ---', template => 'login/signin');
           return;
          }

    # sessionidのアップデート
    my $sid = Sessionid->new->sid;
       $sth_signup_update->execute($sid,$email);

# cookie設定
       $self->cookie('site1'=>"$sid",{httponly => 'true',path => '/', max_age => '31506000', secure => 'true'});

  $self->redirect_to('/menu'); #/menuへリダイレクト
}

sub menusettings {
  my $self = shift;
  #表示のみ テンプレートを共有化の為、emailsetact,unamesetact,passwdsetactと同じもの
  $self->render(msg => '');
}

sub emailset {
  my $self = shift;
  #表示のみ
  $self->render();
}

sub emailsetact {
  my $self = shift;

  my $config = $self->app->plugin('Config');
  my $sth_email_update = $self->app->dbconn->dbh->prepare("$config->{sql_email_update}");   
  my $sth_email_update_sid = $self->app->dbconn->dbh->prepare("$config->{sql_email_update_sid}");

  my $old_email = $self->stash('email');
  my $new_email = $self->param('email');
     $new_email = encode_utf8($new_email);
  my $emailcheck = Inputchk->new($new_email);
     $emailcheck->email;
  my $res_e = $emailcheck->result;
     
     #　入力エラーが在った場合
     if ($res_e > 0 ) {
        $self->app->log->debug('Notice: No good e-mail');
        $self->render(msg => '--- Input Error ---', template => 'login/menusettings');
        return; 
     }

     $new_email = decode_utf8($new_email);

  my $sid = $self->cookie('site1');
    
     $sth_email_update->execute($new_email,$old_email);
     $sth_email_update_sid->execute($new_email,$sid);
     # usercheck()はsidから検索可能かを調べているだけなので、書き換えても問題は無いはず

  #$self->stashはusercheck()で上書きされるはずだが、
     $self->stash( email => $new_email );

  $self->redirect_to('/menu/settings'); #元のページヘ戻る
}

sub unameset {
  my $self = shift;
  #表示のみ
  $self->render();
}

sub passwdset {
  my $self = shift;
  #表示のみ
  $self->render();
}

sub unamesetact {
  my $self = shift;

  my $config = $self->app->plugin('Config');
  my $sth_uname_update = $self->app->dbconn->dbh->prepare("$config->{sql_uname_update}");   
  my $uname = $self->param('username');
     $uname = encode_utf8($uname);
  my $email = $self->stash('email');

  my $unamechk = Inputchk->new($uname);
     $unamechk->ngword;
  my $res_un = $unamechk->result;
     if ( $res_un > 0 ) {
         $self->app->log->debug('Notice: username check error.');
         $self->render(msg => '--- Input Error ---', template => 'login/menusettings');
         return; 
        }
      $uname = decode_utf8($uname);

      $sth_uname_update->execute($uname,$email);

      #$self->stashはusercheck()で上書きされるはずだが、
      $self->stash( username => $uname );

  $self->redirect_to('/menu/settings'); #元のページヘ戻る
}

sub passwdsetact {
  my $self = shift;

  my $config = $self->app->plugin('Config');
  my $sth_passwd_update = $self->app->dbconn->dbh->prepare("$config->{sql_passwd_update}");   
  my $email = $self->stash('email');
  my $passwd = $self->param('password');
     $passwd = encode_utf8($passwd);

  my $passwdchk = Inputchk->new($passwd);
     $passwdchk->password;
  my $res_pass = $passwdchk->result;
     if ( $res_pass > 0 ) {
         $self->app->log->debug('Notice: password check error.');
         $self->render(msg => '--- Input Error ---', template => 'login/menusettings');
         return; 
        }
      $passwd = decode_utf8($passwd);

     $sth_passwd_update->execute($passwd,$email);

  $self->redirect_to('/menu/settings'); #元のページヘ戻る
}


1;
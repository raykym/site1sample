package Site1::Controller::Chatroom;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use DateTime;
use MIME::Base64::URLSafe;
use Data::Dumper;
use Mojo::JSON qw(encode_json decode_json from_json);
use MongoDB;

use Mojo::Pg;
use Mojo::Pg::PubSub;

# 300秒待機設定秒じゃないのか？ミリ秒？どんどん短くなる。。。
#$ENV{MOJO_INACTIVITY_TIMEOUT} = 3000;

sub view {
    my $self = shift;

    $self->render(msg_w => 'morboサーバの場合のみ動作します。　表示のみで履歴は残りません。');
}

my $clients = {};

# websocket
sub echo {
    my $self = shift;
  
    my $username = $self->stash('username');
    my $icon = $self->stash('icon'); #encodeされたままのはず。

       $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
       my $id = sprintf "%s", $self->tx;
       $clients->{$id} = $self->tx;

  # connect message write
      for (keys %$clients) {
        $clients->{$_}->send({json => {
                                 icon => $icon,
                                 username => $username,
                                 hms => 'XX:XX:XX',
                                 text => 'Connect'
                              }});
       }


       # 5分つなぎっぱなし。デフォルトは数秒で切れる
       #Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
       #$self->inactivity_timeout(300);

       $self->on(message => sub {
                  my ($self, $msg) = @_;

                  my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

                  for (keys %$clients) {
                      $clients->{$_}->send({json => {
                              icon => $icon,
                              username => $username,
                              hms => $dt->hms,
                              text => $msg,
                           }}); 
                      }
                  }
         );
             
         $self->on(finish => sub{
                 $self->app->log->debug('Client disconnected');
                 delete $clients->{$id};

              # Disconnect message write
                for (keys %$clients) {
                    $clients->{$_}->send({json => {
                               icon => $icon,
                               username => $username,
                               hms => 'XX:XX:XX',
                               text => 'Has gone.....'
                            }});
                  }
             }
         );
}

sub viewdb {
    my $self = shift;

    $self->render(msg_w => 'Hypnotoadで使えるかも！');
}

# websocket mongodb経由タイプ
sub echodb {
    my $self = shift;

# mongoDBの用意
    my $mongoclient = MongoDB::MongoClient->new(host => 'localhost', port => '27017');
    my $holldb = $mongoclient->get_database('holl_tl');
    my $hollcoll = $holldb->get_collection('holl');
  
    my $username = $self->stash('username');
    my $icon = $self->stash('icon'); #encodeされたままのはず。


       $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
       my $id = sprintf "%s", $self->tx;
       $clients->{$id} = $self->tx;

      # connect message write
#       for (keys %$clients) {
#           $clients->{$_}->send({json => {
#                                 icon => $icon,
#                                 username => $username,
#                                 hms => 'XX:XX:XX',
#                                 text => 'Connect'
#                              }});
#       }
    #日付設定
    my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

       # holldbへの書き込み $iconはurlsafeの状態で記録
       $hollcoll->insert({ icon => $icon, 
                           username => $username, 
                           hms => $dt->hms,
                           text => 'Connect'
                         });

       # 接続時点でのすべてを返す
       my $last = $hollcoll->find_one();
       my $lid = $last->{_id};
       #holldbから差分読み出し
       my $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
       my @allcursol = $datacursol->all;
       foreach my $line (@allcursol){
             $self->tx->send({json => $line });
       }
       $lid = $allcursol[$#allcursol]->{_id};  # 最後のidを更新

       # 5分つなぎっぱなし。デフォルトは数秒で切れる でも1分30秒で切れる
       # 環境変数 MOJO_INECTIVITY_TIMEOUTを設定では出来なかった。。。
       my $stream = Mojo::IOLoop->stream($self->tx->connection);
          $stream->timeout(3600);
          $self->inactivity_timeout(3000);

       Mojo::IOLoop->recurring(
          60 => sub {
             my $char = "dummey";
             my $bytes = $clients->{$id}->build_message($char);
             $clients->{$id}->send( {binary => $bytes}) if ($clients->{$id}->is_websocket);
          });

# on message・・・・・・・
       $self->on(message => sub {
                  my ($self, $msg) = @_;

                  #日付設定 重複記述あり
                  my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

#                  for (keys %$clients) {
#                      $clients->{$_}->send({json => {
#                              icon => $icon,
#                              username => $username,
#                              hms => $dt->hms,
#                              text => $msg,
#                           }});
#                      }
                   # holldbへの書き込み
                   $hollcoll->insert({ icon => $icon, 
                                       username => $username, 
                                       hms => $dt->hms,
                                       text => $msg, 
                                     });
                   # holldbから差分の読み出し
                   $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
                   @allcursol = $datacursol->all;
                   foreach my $line (@allcursol){
                               $self->tx->send({json => $line });
                   }
                   $lid = $allcursol[$#allcursol]->{_id};  # 最後のidを更新
                  }
         );

       #MongoDBからリストを受けて、送信
       my $loopid = Mojo::IOLoop->recurring(
          3 => sub {
              my $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
              my @alldata = $datacursol->all;
              @alldata = reverse(@alldata);  #検索結果をリバースしてDESC同等に
              if ( @alldata ){
                  $clients->{$id}->send({json => @alldata });
                  $lid = $alldata[$#alldata]->{_id};
                  }
              undef @alldata;
             });

# on finish・・・・・・・
         $self->on(finish => sub{
                 $self->app->log->debug('Client disconnected');
                 delete $clients->{$id};

              # Disconnect message write
#                for (keys %$clients) {
#                    $clients->{$_}->send({json => {
#                               icon => $icon,
#                               username => $username,
#                               hms => 'XX:XX:XX',
#                               text => 'Has gone.....'
#                            }});
#                  }
               #日付設定 重複記述あり
                my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

               #holldbへの書き込み
                   $hollcoll->insert({ icon => $icon, 
                                       username => $username, 
                                       hms => $dt->hms,
                                       text => 'Has gone...' 
                                     });
               #更新チェックのループ停止
                if ( ! defined $clients->{$id}){ Mojo::IOLoop->remove($loopid); }
             }
         );

         # mongoDBをポーリングして表示する 失敗　mongojson.plが受け口
         # 書き込みしないと更新されない問題あり。
#         Mojo::IOLoop->timer(1 => sub {
#             my $loop = shift;
#
#             $self->ua->websocket('ws://192.168.0.8:3801' => sub {
#                 my ($ua,$tx) = @_;
#
#                     $tx->on(json => sub{
#                         my ($tx,$dbline) = @_;
#                         $self->tx->send({json => $dbline});
#                  });
#              my $dbline = $self->ua->tx->res->json;
#              if ($dbline != '' ){
#                $self->tx->send({json => $dbline});
#                }
#               });
#         });
#         Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

}

sub viewpg {
    my $self = shift;

    $self->render(msg_w => 'pg経由すぐにリアクションが戻る');
}

sub echopg {
    my $self = shift;

#echodbと同じだが、pubsub通信を利用したPushを利用する。

    # postgresqlの準備
    my $pg = Mojo::Pg->new('postgresql://sitedata:sitedatapass@192.168.0.8/sitedata');
    my $pubsub = Mojo::Pg::PubSub->new(pg => $pg);

    # mongoDBの用意
    my $mongoclient = MongoDB::MongoClient->new(host => 'localhost', port => '27017');
    my $holldb = $mongoclient->get_database('holl_tl');
    my $hollcoll = $holldb->get_collection('holl');
  
    #param 認証をパスしているので、username,icon,emailがstashされている。
    my $username = $self->stash('username');
    my $icon = $self->stash('icon'); #encodeされたままのはず。


       $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
       my $id = sprintf "%s", $self->tx;
       $clients->{$id} = $self->tx;

    # connect message write
    #日付設定
    my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

       # holldbへの書き込み $iconはurlsafeの状態で記録
       $hollcoll->insert({ icon => $icon, 
                           username => $username, 
                           hms => $dt->hms,
                           text => 'Connect'
                         });
       # 書き込みを通知
       $pubsub->notify( messagetl => 'send message');

       # 接続時点でのすべてを返す
    my $last = $hollcoll->find_one();
    my $lid = $last->{_id};
       #holldbから差分読み出し
    my $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
    my @allcursol = $datacursol->all;
       foreach my $line (@allcursol){
             $self->tx->send({json => $line });
       }
       $lid = $allcursol[$#allcursol]->{_id};  # 最後のidを更新

       # 5分つなぎっぱなし。デフォルトは数秒で切れる でも1分30秒で切れる
       # 環境変数 MOJO_INECTIVITY_TIMEOUTを設定では出来なかった。。。
       my $stream = Mojo::IOLoop->stream($self->tx->connection);
          $stream->timeout(3600);
          $self->inactivity_timeout(3000);
       #つなぎっぱなしの為のループ
       Mojo::IOLoop->recurring(
          60 => sub {
             my $char = "dummey";
             my $bytes = $clients->{$id}->build_message($char);
             $clients->{$id}->send( {binary => $bytes}) if ($clients->{$id}->is_websocket);
          });

       #pubsubから受信設定 messagetlをキーとして利用
    my $cb = $pubsub->listen(messagetl => sub {
            my ($pubsub, $payload) = @_;
            #$payloadは通知のみで意味を利用しない
            # holldbから差分の読み出し
               $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
               @allcursol = $datacursol->all;
            my @alldata = reverse(@allcursol);  #検索結果をリバースしてDESC同等に
               foreach my $line (@alldata){
                           $self->tx->send({json => $line });
                   }
               $lid = $allcursol[$#allcursol]->{_id};  # 最後のidを更新
        });

# on message・・・・・・・
       $self->on(message => sub {
                  my ($self, $msg) = @_;

                  #日付設定 重複記述あり
                  my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

                   # holldbへの書き込み
                   $hollcoll->insert({ icon => $icon, 
                                       username => $username, 
                                       hms => $dt->hms,
                                       text => $msg, 
                                     });
                   # 書き込みを通知
                   $pubsub->notify( messagetl => 'send message');
                  }
         );

       #MongoDBからリストを受けて、送信 pubsubで代用の為コメントアウト
 #      my $loopid = Mojo::IOLoop->recurring(
 #         3 => sub {
 #             my $datacursol = $hollcoll->find({_id => { '$gt' => $lid }});
 #             my @alldata = $datacursol->all;
 #             @alldata = reverse(@alldata);  #検索結果をリバースしてDESC同等に
 #             if ( @alldata ){
 #                 $clients->{$id}->send({json => @alldata });
 #                 $lid = $alldata[$#alldata]->{_id};
 #                 }
 #             undef @alldata;
 #            });

# on finish・・・・・・・
         $self->on(finish => sub{
                 $self->app->log->debug('Client disconnected');
                 delete $clients->{$id};

               #日付設定 重複記述あり
                my $dt = DateTime->now( time_zone => 'Asia/Tokyo');

               #holldbへの書き込み
                   $hollcoll->insert({ icon => $icon, 
                                       username => $username, 
                                       hms => $dt->hms,
                                       text => 'Has gone...' 
                                     });
               # 書き込みを通知
               $pubsub->notify( messagetl => 'send message');

               #更新チェックのループ停止
         ###       if ( ! defined $clients->{$id}){ Mojo::IOLoop->remove($loopid); }
               # pubsubリスナーの停止
                if ( ! defined $clients->{$id}){ $pubsub->unlisten(messagetl => $cb); }
             }
         );
}

sub signaling {
    my $self = shift;

    # webRTC用にシグナルサーバとしてJSONを受けてそのままJSONを届ける
    # pubsubの振り分けについて検討中
    # セッションテーブルをPGのsignal_tblに作成。websocket切断で削除される。

    #cookieからsid取得
    my $sid = $self->cookie('site1');
    ###$self->app->log->debug("DEBUG: SID: $sid");

    #websocket 確認
    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx->connection;
    $clients->{$id} = $self->tx;

    # postgresqlの準備
        my $pg = Mojo::Pg->new('postgresql://sitedata:sitedatapass@192.168.0.8/sitedata');
        my $pubsub = Mojo::Pg::PubSub->new(pg => $pg);
        my $subscall = Mojo::Pg::PubSub->new(pg => $pg);

    #リスナー登録　pgのsignal_tblへsidを登録
        $pg->db->query('INSERT INTO signal_tbl (sessionid) values(?)',$sid);


    # 接続維持設定 WebRTCではICE交換が終わればすぐにwebsocketは閉じたい。
#       my $stream = Mojo::IOLoop->stream($self->tx->connection);
#          $stream->timeout(3000);
#          $self->inactivity_timeout(3000);
       #つなぎっぱなしの為のループ  ・・・ つながれば切れてOKなので
#       Mojo::IOLoop->recurring(
#          60 => sub {
#             my $char = "dummey";
#             my $bytes = $clients->{$id}->build_message($char);
#             $clients->{$id}->send( {binary => $bytes}) if ($clients->{$id}->is_websocket);
#          });

    #pubsubから受信設定 
        my $cb = $pubsub->listen($sid => sub {
            my ($pubsub, $payload) = @_;

            #JSONキャラ->perl形式
            my $jsonobj = from_json($payload);

              my $connid = $self->tx->connection;
                 $self->app->log->debug("DEBUG: go session: $connid");
             #    $self->app->log->debug("DEBUG: payload: $payload");

                 #websocketは自分にだけ送信する
                 $clients->{$id}->send({ json => $jsonobj});
          });

    # on message・・・・・・・
       $self->on(message => sub {
                  my ($self, $msg) = @_;
                   # $msgはJSONキャラを想定
                   #my $jsonobj = from_json($msg);
                 my $connid = $self->tx->connection;
                   $self->app->log->debug("DEBUG: on session: $connid");
              #     $self->app->log->debug("DEBUG: msg: $msg");

              # 書き込みを通知 signal_tblにsubscriberされたidのみ通知
              # 自分は除外する。
        my $subs_member = $pg->db->query('SELECT * FROM signal_tbl');
              while ( my $subs_id = $subs_member->hash){
                   $pubsub->notify( $subs_id->{sessionid} => $msg) unless ($sid eq $subs_id->{sessionid});
                   $self->app->log->debug("DEBUG: subs_id: $subs_id->{sessionid}");
              }
          });

    # on finish・・・・・・・
         $self->on(finish => sub{
               my ($self, $msg) = @_;

               $self->app->log->debug('Client disconnected');
               delete $clients->{$id};

               # pubsubリスナーの停止
               if ( ! defined $clients->{$id}){ $pubsub->unlisten(signalon => $cb); }
               # リスナー登録の解除
               $pg->db->query('DELETE FROM signal_tbl WHERE sessionid = ?' , $sid);
        });

}

1;

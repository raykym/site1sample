package Site1::Controller::Webroom;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use Mojo::JSON qw(encode_json decode_json from_json to_json);
use Mojo::Pg::PubSub;
use Mojo::Util qw(dumper encode decode url_escape url_unescape md5_sum sha1_sum);

my $tablename;
my $clients = {};

sub signaling {
  my $self = shift;

     #Chatroom.pmのsignaringとroomentrylistをマージした処理を作る。

    #cookieからsid取得 認証を経由している前提
    my $sid = $self->cookie('site1');
       $self->app->log->debug("DEBUG: SID: $sid");
    my $username = $self->stash('username');
    my $icon = $self->stash('icon');
    my $icon_url = $self->stash('icon_url');
       $icon_url = "/imgcomm?oid=$icon" if (! defined $icon_url);

    #websocket 確認
       $self->app->log->debug(sprintf 'Client connected: %s', $self->tx->connection);
       my $id = sprintf "%s", $self->tx;
          $self->app->log->debug("socket id: $id");
      $clients->{$id} = $self->tx;

    # トランザクションidをpubsubの受信に利用する
    my $connid = $self->tx->connection;

    # postgresqlの準備 Site1.pmに共通設定追加
        my $pg = $self->app->pgdbh;
        my $pubsub = Mojo::Pg::PubSub->new(pg => $pg);

    # WebSocket接続維持設定
       my $stream = Mojo::IOLoop->stream($self->tx->connection);
          $stream->timeout(3000);
          $self->inactivity_timeout(3000);

    #pubsubから受信設定
        my $cb = $pubsub->listen($connid => sub {
            my ($pubsub, $payload) = @_;

            #JSONキャラ->perl形式
            my $jsonobj = from_json($payload);

               $self->app->log->debug("DEBUG: go session: $connid");
               $self->app->log->debug("DEBUG: payload: $payload");

               #websocket送信 perl形式->jsonへ変換されている。text => $payloadも同じ気がするが。。。
               $clients->{$id}->send({json => $jsonobj});
          });

   #イベント駆動の部分は時系列が分かり難い タイミングとしてエラーが出る想定。。。
               my $res = $pg->db->query("SELECT * FROM connidroom_tbl WHERE connid = ?", $connid); 
               my $resline = $res->hash; # 1個の想定
                  $tablename = $resline->{tablename} if ($resline->{tablename});

    # エントリーメンバー一覧を返す処理 global変数として残す
    my $result;
    my @memberlist;

    # on message・・・・・・・
       $self->on(message => sub {
                  my ($self, $msg) = @_;
                   # $msgはJSONキャラを想定
                   my $jsonobj = from_json($msg);
                   $self->app->log->debug("DEBUG: on session: $connid");
                   $self->app->log->debug("DEBUG: msg: $msg");

           # room作成
           if ( $jsonobj->{entry} ) {

                   #重複入力の除外（リロードすればconnidroom_tblから除外されて再入力可能に成る）
                   my $reschk = $pg->db->query("SELECT roomname FROM connidroom_tbl WHERE connid = ?", $connid);
                   if ($reschk->rows >= 1) { return; } #エントリー済ならパス

                   #room名が既に登録されているか？
                   my $roomname = qq($jsonobj->{entry});
                   my $result = $pg->db->query("SELECT tablename FROM connidroom_tbl WHERE roomname = ?",$roomname);
                   my $restable = $result->hash;   #1個の想定
                   my $tablename = $restable->{tablename};
                      $self->app->log->debug("Get connidroom tablename: $tablename");
                   # 後置ifで振り分け
                   my $cnt = 1;
                      $cnt = 0 if (! defined $tablename);
                      $self->app->log->debug("if get tablename? $cnt");

                   # テーブル名は時刻をハッシュ化してテンポラリに作成
                   my $chksum = md5_sum time if ($cnt == 0);
                      $self->app->log->debug("Entry chksum: $chksum") if ($cnt == 0);
                    # 上かここで設定される
                      $tablename = "room_".$chksum."_tbl" if ($cnt == 0);
                      $self->app->log->debug("TABLENAME: $tablename") if ($cnt == 0);

                   my @connvalue = ($self->tx->connection,$jsonobj->{entry},$tablename); 
                   $pg->db->query("INSERT INTO connidroom_tbl values(?,?,?)",@connvalue); 


                   $pg->db->query("CREATE TABLE IF NOT EXISTS $tablename (connid text, sessionid text,username varchar(255),icon_url char(255), ready boolean DEFAULT false)");
                   $self->app->log->debug("DEBUG: CREATE TABLE $tablename");

                my @values = ($connid, $sid, $username, $icon_url);
       #            $self->app->log->debug("DEBUG: @values");

                #リスナー登録　pgのsignal_tblへsidを登録 
                   $pg->db->query("INSERT INTO $tablename values(?,?,?,?)",@values);
              } # $jsonobj->{entry}

              if ($jsonobj->{setReady}) {
               # $tablenameが必要に成る度に検索が必要、サブルーチン内だから。
               my $res = $pg->db->query("SELECT * FROM connidroom_tbl WHERE connid = ?", $connid); 
               my $resline = $res->hash; # 1個の想定
                  $tablename = $resline->{tablename} if ($resline->{tablename});

               # readyフラグのセット
                 my $setreadyconn = $jsonobj->{setReady};
                    $self->app->log->debug("setreadyconn: $setreadyconn");
                 $pg->db->query("UPDATE $tablename SET ready = 'true' WHERE connid = ?",$setreadyconn);

                 return;

              } # setReady


               # fromとしてconnidを付加
                   $jsonobj->{from} = $connid;
                   $msg = to_json($jsonobj);
                   $self->app->log->debug("DEBUG: msgaddid: $msg");

                if ($jsonobj->{sendto}){
                   #個別送信が含まれる場合、単独送信
                   $pubsub->notify( $jsonobj->{sendto} => $msg);
  
                   return;  # スルーすると全体通信になってしまう。
                   } 
             # 個別では無い場合！！！
             # 書き込みを通知 signal_tblにsubscriberされたidのみ通知
             # 自分は除外する。
                   my $res = $pg->db->query("SELECT * FROM connidroom_tbl WHERE connid = ?", $connid); 
                   my $resline = $res->hash; 
                   my $tablename = $resline->{tablename} if ( $resline->{tablename});
                my $subs_member = $pg->db->query("SELECT * FROM $tablename");
                  while ( my $subs_id = $subs_member->hash){
                       $pubsub->notify( $subs_id->{connid} => $msg) unless ($connid eq $subs_id->{connid});
                       $self->app->log->debug("DEBUG: subs_id: $subs_id->{connid}") unless ($connid eq $subs_id->{connid});
                           }


        #エントリーメンバーを送信コマンドの受信
             if ($jsonobj->{getlist}){
               my $res = $pg->db->query("SELECT * FROM connidroom_tbl WHERE connid = ?", $connid); 
               my $resline = $res->hash; # 1個の想定
                  $tablename = $resline->{tablename} if ($resline->{tablename});
        ##          $self->app->log->debug("loop tablename: $tablename");

                $result = $pg->db->query("SELECT connid,sessionid,username,icon_url,ready FROM $tablename") if ($tablename);

              while (my $next = $result->hash){
                    push @memberlist, to_json({sessionid => $next->{sessionid}, username => $next->{username}, icon_url => $next->{icon_url}, connid => $next->{connid}, ready => $next->{ready}});
          #         $self->app->log->debug("memberlist: $next->{connid} $next->{username} $next->{icon_url}");
                } #while

              # 配列で１ページ分を送る。
             my $memberlist_json = to_json( { from => $connid, type => "reslist", reslist => [@memberlist] } );    
        #        $self->app->log->debug("send jsontext: $memberlist_json");
                $clients->{$id}->send($memberlist_json);

                @memberlist = (); #空にする
                $result = {}; #エラー消える。 何故？

                 return;
                } 

                }); # onmessageのはず。。。

    # on finish・・・・・・・
         $self->on(finish => sub{
               my ($self, $msg) = @_;

               $self->app->log->debug('Client disconnected');
               delete $clients->{$id};

               # テーブル名取得 ここは必要らしい
               my $res = $pg->db->query("SELECT * FROM connidroom_tbl WHERE connid = ?", $connid); 
               my $resline = $res->hash; 
               my $tablename = $resline->{tablename} if ( $resline->{tablename});
                  $self->app->log->debug("pre del tablename: $tablename");

               # pubsubリスナーの停止
               if ( ! defined $self->tx){ $pubsub->unlisten($connid => $cb); }
               # リスナー登録の解除 
               $pg->db->query("DELETE FROM $tablename WHERE connid = ?" , $connid);
               $self->app->log->debug("DELETE entry: $tablename : $connid");

               $result = $pg->db->query("SELECT * FROM $tablename");
               my $cnt = $result->rows;
               $self->app->log->debug("$tablename REMAIN entry $cnt");

               if ($cnt == 0){
                  $self->app->log->debug("NULL TABLE DELETE!  $tablename");
                  $pg->db->query("DROP TABLE $tablename");
               }

               $pg->db->query("DELETE FROM connidroom_tbl WHERE connid = ?" , $connid);
               $self->app->log->debug("del entry: $connid");

        });  # onfinish...



#  $self->render(msg => '');
}

1;

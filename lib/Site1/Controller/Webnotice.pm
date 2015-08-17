package Site1::Controller::Webnotice;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use Mojo::JSON qw(encode_json decode_json from_json to_json);
use Mojo::Pg::PubSub;
use Mojo::Util qw(dumper encode decode url_escape url_unescape md5_sum sha1_sum);

sub view {
   my $self = shift;

   $self->render(msg => 'websocket reconnect TEST');
}

sub webnotice {
  my $self = shift;

  # つなぎっぱなしのwebsocketまたは再接続可能な構造を探る。
  # 結果、再接続ではpostgresqlのコネクションを保持して、消費してしまう。
  # つなぎっぱなしで通知する仕組み（メールに変わるもの、リンガーのつもり）
  
  my $sid = $self->cookie('site1');
     $self->app->log->debug("DEBUG: SID: $sid");
  my $username = $self->stash('username');
  my $icon = $self->stash('icon');
  my $icon_url = $self->stash('icon_url');
     $icon_url = "/imgcomm?oid=$icon" if (! defined $icon_url);

  #wensocket 確認
  $self->app->log->debug(sprintf 'Client connected: %s', $self->tx->connection);
  
  # WebSocket接続維持設定
     my $stream = Mojo::IOLoop->stream($self->tx->connection);
        $stream->timeout(60);
        $self->inactivity_timeout(3000);

  # postgresqlの準備 Site1.pmに共通設定追加
     my $pg = $self->app->pg;
     my $pubsub = Mojo::Pg::PubSub->new(pg => $pg);

  #pubsubから受信設定 sidで受信
     my $cb = $pubsub->listen($sid => sub {
              my ($pubsub, $payload) = @_;

              #JSONキャラ->perl形式
              my $jsonobj = from_json($payload);

               $self->app->log->debug("DEBUG: go session: $sid");
               $self->app->log->debug("DEBUG: payload: $payload");

               #websocket送信 perl形式->jsonへ変換されている。text => $payloadも同じ気がするが。。。
               $self->tx->send({json => $jsonobj});
          });

    # on message・・・・・・・
       $self->on(message => sub {
                  my ($self, $msg) = @_;
                   # $msgはJSONキャラを想定
                   my $jsonobj = from_json($msg);
                   $self->app->log->debug("DEBUG: on session: $sid");
                   $self->app->log->debug("DEBUG: msg: $msg");

       });  # onmessage

  # on finish・・・・・・・
       $self->on(finish => sub{
               my ($self, $msg) = @_;

               $self->app->log->debug('Client disconnected');

               # pubsubリスナーの停止
               $pubsub->unlisten($sid => $cb);
   
       }); # onfinish

  return;
}

1;

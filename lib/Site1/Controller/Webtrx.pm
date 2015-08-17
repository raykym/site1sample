package Site1::Controller::Webtrx;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

use Mojo::Pg::Pubsub;

# 認証も何もなく、ただ、アクセスすると音声がつながるトランシーバのようなページ
# pubsubで誰かが接続する度にリロードを強制して再接続を行う。仕様でとにかく単純につなぐことを目的としたページ。

sub webtrx {
    my $self = shift;

    $self->render();
}

sub websocket {
    my $self = shift;

    my $connid = $self->tx->connection;

     


}

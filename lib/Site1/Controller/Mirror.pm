package Site1::Controller::Mirror;
use Mojo::Base 'Mojolicious::Controller';

sub mirror {
  my $self = shift;
  #ローカルカメラを表示するページ
  $self->render(msg => 'カメラからの表示をそのままブラウザに出しています。');
}

1;

package Site1::Controller::Top;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub top {
  my $self = shift;

  $self->stash(clietnid =>'861600582037-i6qsq0tk7eqplaohomthm0e61he567jk.apps.googleusercontent.com');
  $self->stash(secclient => 'ynd0015uuH0TQDwQ6gPZMKr9');
  $self->render(msg => 'Welcome to this site!');
}

sub mainmenu {
    my $self = shift;

    $self->render(msg => 'OPEN the Menu!');
}

sub unknown {
    my $self = shift;
    # 未定義ページヘのアクセス
    $self->render();
}

1;

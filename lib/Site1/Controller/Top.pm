package Site1::Controller::Top;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub top {
  my $self = shift;

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

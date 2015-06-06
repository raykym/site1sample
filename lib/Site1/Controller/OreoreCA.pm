package Site1::Controller::OreoreCA;
use Mojo::Base 'Mojolicious::Controller';

sub download {
  my $self = shift;

     $self->res->headers->content_type('text/plain');

     $self->res->content->asset(Mojo::Asset::File->new(path => '/home/debian/perlwork/mojowork/server/site1/public/oreoreCA/oreoreCAcert.der'));
     $self->rendered(200);
}

1;

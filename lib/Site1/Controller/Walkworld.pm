package Site1::Controller::Walkworld;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use Mojo::JSON qw(encode_json decode_json from_json to_json);
use Encode;
#use MongoDB;
use DateTime;

# mongoDBの用意
   # my $mongoclient = MongoDB::MongoClient->new(host => '192.168.0.5', port => '27017');

# This action will render a template
sub view {
  my $self = shift;

  $self->render(msg_w => '');
}

sub echo {
    my $self = shift;

#    my $mongoclient = MongoDB->connect('mongodb://192.168.0.5:27017');
    my $wwdb = $self->app->mongoclient->get_database('WalkWorld');
    my $timelinecoll = $wwdb->get_collection('MemberTimeLine');

  $self->on(message => sub {
        my ($self,$msg) = @_;
  

           my $jsonobj = from_json($msg);
  
           $self->app->log->debug("DEBUG: msg: $msg");

           $timelinecoll->insert_one($jsonobj);
  });

  $self->on(finish => sub {
        my ($self,$msg) = @_;

        $self->app->log->debug("DEBUG: On finish!!");
        undef $self->tx->connection;
        undef $self->tx;
  });

  my $stream = Mojo::IOLoop->stream($self->tx->connection);
        $stream->timeout(0);  # no timeout!
        $self->inactivity_timeout(3000);

#  Mojo::IOLoop->recurring(
#          50 => sub {
#             my $jsonobj = { "dummey" => "dummey" };
#             $self->tx->send( { json => $jsonobj });
#          });

}

1;

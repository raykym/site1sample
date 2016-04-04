package Site1::Controller::Timeline;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use Mojo::JSON qw(encode_json decode_json from_json to_json);
use Encode;
use MongoDB;
use DateTime;

# mongoDBの用意
    my $mongoclient = MongoDB::MongoClient->new(host => 'localhost', port => '27017');

# This action will render a template
sub view {
  my $self = shift;

  $self->render(msg_w => '');
}

sub record {
  my $self = shift;

  my $jsonobj = { "dummey" => "dummey" };
     $self->tx->send( { json => $jsonobj });

  my $uid = $self->stash('uid');
  my $dt = DateTime->now( time_zone => 'Asia/Tokyo');
  my $colname = $uid.$dt->ymd;

  my $timelinedb = $mongoclient->get_database('TimeLine');
  my $timelinecoll = $timelinedb->get_collection("$colname");

  $self->on(message => sub {
        my ($self,$msg) = @_;
           my $jsonobj = from_json($msg);
  
           $self->app->log->debug("DEBUG: msg: $msg");

           $timelinecoll->insert($jsonobj);

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

  Mojo::IOLoop->recurring(
          50 => sub {
             my $jsonobj = { "dummey" => "dummey" };
             $self->tx->send( { json => $jsonobj });
          });
}

sub chrome {
  # for chrome App
  # not userchecked
  my $self = shift;

  my $jsonobj = { "dummey" => "dummey" };
     $self->tx->send( { json => $jsonobj });

  my $dt = DateTime->now( time_zone => 'Asia/Tokyo');
  my $colname = $dt->ymd;

  my $timelinedb = $mongoclient->get_database('TimeLine');
  my $timelinecoll = $timelinedb->get_collection("$colname");

  $self->on(message => sub {
        my ($self,$msg) = @_;
           my $jsonobj = from_json($msg);
  
           $self->app->log->debug("DEBUG: msg: $msg");

           $timelinecoll->insert($jsonobj);

    });

  $self->on(finish => sub {
        my ($self,$msg) = @_;

        $self->app->log->debug("DEBUG: On finish!!");
        undef $self->tx->connection;
        undef $self->tx;
   });

  my $stream = Mojo::IOLoop->stream($self->tx->connection);
        $stream->timeout(60); 
        $self->inactivity_timeout(3000);

  Mojo::IOLoop->recurring(
          50 => sub {
             my $jsonobj = { "dummey" => "dummey" };
             $self->tx->send( { json => $jsonobj });
             $self->app->log->debug("DEBUG: chrome: send dummey!!");
          });
}

sub mapview {
    my $self = shift;

    $self->render(msg_w => '');
}

sub echo {
    my $self = shift;


}

1;

package Site1::Controller::Walkworld;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use Mojo::JSON qw(encode_json decode_json from_json to_json);
use Encode;
#use MongoDB;
use DateTime;
use Data::Dumper;

# mongoDBの用意  Site1.pmで定義
   # my $mongoclient = MongoDB::MongoClient->new(host => '192.168.0.5', port => '27017');

# This action will render a template
sub view {
  my $self = shift;

  $self->render(msg_w => '');
}

sub echo2 {
    # websocketテスト用
    my $self = shift;

    my $test = { "test" => "testcoment" };
       $self->tx->send({json => $test });


    $self->on(message => sub {
        my ($self,$msg) = @_;

    my $test = { "test" => "test on message" };
       $self->tx->send({json => $test });
        });

    $self->on(finish => sub {
        my ($self,$msg) = @_;

        });
}



my $clients = {};

sub echo {
    my $self = shift;

       $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx->connection;
       $clients->{$id} = $self->tx;

    my $wwdb = $self->app->mongoclient->get_database('WalkWorld');
    my $timelinecoll = $wwdb->get_collection('MemberTimeLine');

    my $wwlogdb = $self->app->mongoclient->get_database('WalkWorldLOG');
    my $timelinelog = $wwlogdb->get_collection('MemberTimeLinelog');


  $self->on(message => sub {
        my ($self,$msg) = @_;

           my $jsonobj = from_json($msg);

           # TTLレコードを追加する。
           $jsonobj = { %$jsonobj,ttl => DateTime->now() };  

           $self->app->log->debug("DEBUG: msg: $msg");


           # 現状の情報を送信
           my $geo_points_cursole = $timelinecoll->query({ "geometry" => { 
                                           '$nearSphere' => [ $jsonobj->{loc}->{lng} , $jsonobj->{loc}->{lat} ], 
                                           '$maxDistance' => 0.0009 
                                         }});
          #    $self->app->log->debug("DEBUG: MongoDB find.");
          #        my @geo_points = $geo_points_cursole->all;
          #        my $ddump = Dumper(@geo_points);
          #        $self->app->log->debug("DEBUG: Dumper: $ddump");

          #    $self->app->log->debug("DEBUG: GEO points send###################");

                   my @pointlist = $geo_points_cursole->all;
                   my $listhash = { 'pointlist' => \@pointlist };
                   my $jsontext = to_json($listhash); 
                      $self->tx->send($jsontext);
                      $self->app->log->debug("DEBUG: geo_points: $jsontext");


                    #   while ( my $line = $geo_points_cursole->next ){
                    #          my $jsontext = to_json($line);
                    #          if (defined $line) { 
                    #                         $self->tx->send($jsontext);
                    #          } else { last ; } 
                    #          $self->app->log->debug("DEBUG: geo_points: $jsontext");
                    #    } #while

           # TTl DB
           $timelinecoll->insert($jsonobj);
           # LOG用DB
           $timelinelog->insert($jsonobj);

  }); # on message

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
#          60 => sub {
#          my $dummyobj = { "dummy" => "dummy" }; 
#          $self->tx->send( { json => $dummyobj } );
#          });


} # echo

1;

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use lib '/storage/perlwork/mojowork/server/site1/lib';
use lib '/storage/perlwork/mojowork/server/site1/t';

my $t = Test::Mojo->new('Site1');

   $t->websocket_ok('/menu/chatroom/echo')
     ->send_ok('signal')
     ->message_ok
     ->message_is('signal')
     ->finish_ok;

done_testing;

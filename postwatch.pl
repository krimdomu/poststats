#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use Config::General;
use DBI;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/vendor/dm4p";
use lib "$FindBin::Bin/vendor/dm4p-adapter-mysql";

use Mail::Log::Postfix;
use Data::Dumper;
use Exception::Class;

use DM4P;
use DM4P::Adapter::MySQL;

sub write_db_entry;

my $maillog = Mail::Log::Postfix->new(file => $ARGV[0]);
my $conf  = Config::General->new("$FindBin::Bin/conf/postwatch.conf");
my %config = $conf->getall();

DM4P::setup(default => 'MySQL://' . $config{'db'}->{'host'} . '/' . $config{'db'}->{'database'} 
			. '?username=' . $config{'db'}->{'user'} 
			. '&password=' . $config{'db'}->{'password'});

my $db = DM4P::get_connection();
eval {
	$db->connect();
};

my $e;
if($e = Exception::Class->caught('DM4P::Exception::Connect')) {
	print $e->error . "\n";
	exit 1;
}

while(my $row = $maillog->next) {
	write_db_entry($row);
}

sub write_db_entry {
	my $data = shift;
	my $insert = DM4P::SQL::Query::INSERT->new()
			->table($config{'db'}->{'table'})
				->date($data->{'date'})
				->size($data->{'size'})
				->client($data->{'client'})
				->status($data->{'status'})
				->to($data->{'to'})
				->relay($data->{'relay'})
				->from($data->{'from'})
				->queue_id($data->{'queue-id'})
				->code($data->{'code'})
				->message_id($data->{'message-id'});

	my $stm = $db->get_statement($insert);
	$stm->execute();
}


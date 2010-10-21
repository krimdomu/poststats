package Mail::Log::Postfix;

use strict;
use warnings;

use Data::Dumper;
use IO::File;
use DateTime;
use DateTime::Format::Strptime qw(strptime);

use Mail::Log::Postfix::LogEntry;
use Mail::Log::Postfix::LogEntry::Base;
use Mail::Log::Postfix::LogEntry::Client;
use Mail::Log::Postfix::LogEntry::From;
use Mail::Log::Postfix::LogEntry::MessageId;
use Mail::Log::Postfix::LogEntry::Removed;
use Mail::Log::Postfix::LogEntry::To;
use Mail::Log::Postfix::LogEntry::Undefined;

sub new {
	my $that = shift;
	my $proto = ref($that) || $that;
	my $self = { @_ };

	bless($self, $proto);

	$self->{'__fh'} = IO::File->new();
	$self->{'__fh'}->open("< ". $self->file);
	
	$self->{'__mails'} = [];

	unless($self->{'__fh'}) {
		die("Can't open file: " . $self->file);
	}
	$self->_read();

	$self->{'__line'} = 0;

	return $self;
}

sub DESTROY {
	my $self = shift;
	$self->fh->close;
}

sub file {
	my $self = shift;
	return $self->{"file"};
}

sub fh {
	my $self = shift;
	return $self->{'__fh'};
}

sub _read {
	my $self = shift;
	
	my $fh = $self->fh;
	my $mails = {};
	while(my $line = <$fh>) {
		my $o = Mail::Log::Postfix::LogEntry->new($self->_parse_line($line))->get();
		if($o->type eq "client") {
			$mails->{$o->queue_id} = {};
			$mails->{$o->queue_id}->{'client'} = $o->host;
			my $dt = strptime("%b %d %H:%M:%S %Y", $o->date . ' ' . DateTime->now->year);
			$mails->{$o->queue_id}->{'date'} = $dt->ymd('-') . ' ' . $dt->hms(':');
		}

		if($o->type eq "from") {
			$mails->{$o->queue_id}->{"from"} = $o->from;
			$mails->{$o->queue_id}->{"size"} = $o->size;
		}

		if($o->type eq "to") {
			$mails->{$o->queue_id}->{"to"} = $o->to;
			$mails->{$o->queue_id}->{"relay"} = $o->relay;
			$mails->{$o->queue_id}->{"status"} = $o->status;
			$mails->{$o->queue_id}->{"code"} = $o->code;
		}

		if($o->type eq "message-id") {
			$mails->{$o->queue_id}->{"message-id"} = $o->message_id;
		}

		if($o->type eq "removed") {
			$mails->{$o->queue_id}->{"queue-id"} = $o->queue_id;
			push(@{$self->{"__mails"}}, $mails->{$o->queue_id});
			$mails->{$o->queue_id} = undef;
			delete $mails->{$o->queue_id};
		}
	}
}

sub next {
	my $self = shift;

	return $self->{'__mails'}->[$self->{'__line'}++];
}

sub search {
	my $self = shift;
	my $s = { @_ };

	while(my $row = $self->next) {
		if($row->{'message-id'} eq $s->{'message_id'}) {
			return 1;
		}
	}

	$self->{'__line'} = 0;
	return 0;
}


sub _parse_line {
	my $self = shift;
	my $line = shift;

	chomp $line;
	my @data = ($line =~ m/^([a-zA-Z]{3} \d{1,2} \d{1,2}:\d{1,2}:\d{1,2}) ([a-zA-Z0-9\-]+) ([a-zA-Z0-9\-]+)\/([a-zA-Z0-9\-]+)\[(\d+)\]: (([A-Z0-9]+): (client|from|message\-id|to|removed)(=(((?<=from\=)\<(.*?)\>, size=(\d+)|(?<=message\-id\=)\<(.*?)\>|(?<=to\=)\<(.*?)\>, relay=(.*?)\[(.*?)\]:(\d+), delay=(.*?), delays=(.*?), dsn=(.*?), status=([a-zA-Z0-9]+)( \((\d+) (.*)\))?)|([a-z0-9\.\-]+)\[(.*?)\]))?)?(.*)$/);


=begin
	@data = qw(
		DATE
		HOST
		POSTFIX-INSTANCE
		PROC
		PID,
		undef | string,   (undef -> keine weiteren infos vorhanden)
		QUEUE-ID,
		TYPE             (client, from, message-id, to)     <<----- IDX: 7
	);

	# WENN TYPE == client
	@data = qw(
		STRING,           (=hostname[IP])
		STRING,           (hostname[IP])
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		HOSTNAME,
		IP,
		LEER-STRING
	)

	# WENN TYPE == message-id
	@data = qw(
		STRING,            (=<Message-ID>),
		STRING,            (<Message-ID>),
		STRING,            (<Message-ID>),
		undef,
		undef,
		STRING,            (Message-ID),
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		LEER-STRING
	)

	# WENN TYPE == from
	@data = qw(
		STRING,            (=<from>, size=\d+)
		STRING,            (<from>, size=\d+)
		STRING,            (<from>, size=\d+)
		STRING,            (from)
		INT,               (size)
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		STRING           (Restlicher Text der Zeile)
	)

	# WENN TYPE == to
	@data = qw(
		STRING,           (=<to>, relay=..., delay=..., delays=..., dsn=..., status=... (infos)
		STRING,           (<to>, relay=..., delay=..., delays=..., dsn=..., status=... (infos)
		STRING,           (<to>, relay=..., delay=..., delays=..., dsn=..., status=... (infos)
		undef,
		undef,
		undef,
		STRING,           (to)
		STRING,           (relay)
		STRING,           (relay-ip)
		INT,              (relay-port)
		FLOAT,            (delay)
		STRING,           (delays, z.b. 0.05/0.01/0.61/0.9)
		STRING,           (dsn)
		STRING,           (status)
		STRING,
		INT,              (status code)
		STRING,           (die restliche zeile)
		undef,
		undef,
		undef,
		LEER-STRING
	)
=cut
	return @data;
}

1;

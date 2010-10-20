package Mail::Log::Postfix::LogEntry;

use strict;
use warnings;
use Data::Dumper;

sub new {
	my $that = shift;
	my $proto = ref($that) || $that;
	my $self = {};

	bless($self, $proto);

	@{$self->{'__data'}} = @_;

	return $self;
}

sub type {
	my $self = shift;
	if(!$self->{'__data'}->[5]) {
		return 'line';
	}
	return $self->{'__data'}->[7];
}

sub get {
	my $self = shift;
	my $o;
	if($self->type eq 'client') {
		$o = Mail::Log::Postfix::LogEntry::Client->new(
			host => $self->{'__data'}->[25],
			ip => $self->{'__data'}->[26]
		);
	} elsif($self->type eq 'from') {
		$o = Mail::Log::Postfix::LogEntry::From->new(
			from => $self->{'__data'}->[11],
			size => $self->{'__data'}->[12],
		);
	} elsif($self->type eq 'to') {
		$o = Mail::Log::Postfix::LogEntry::To->new(
			to => $self->{'__data'}->[14],
			relay => $self->{'__data'}->[15],
			relay_ip => $self->{'__data'}->[16],
			relay_port => $self->{'__data'}->[17],
			delay => $self->{'__data'}->[18],
			delays => $self->{'__data'}->[19],
			dsn => $self->{'__data'}->[20],
			status => $self->{'__data'}->[21],
			code => $self->{'__data'}->[23]
		);
	} elsif($self->type eq 'message-id') {
		$o = Mail::Log::Postfix::LogEntry::MessageId->new(
			message_id => $self->{'__data'}->[13],
		);
	} elsif($self->type eq 'removed') {
		$o = Mail::Log::Postfix::LogEntry::Removed->new();
	}

	$o = Mail::Log::Postfix::LogEntry::Undefined->new(line => pop(@{$self->{'__data'}})) if ! $o;
	$o->set_data(@{$self->{'__data'}});

	return $o;
}

sub AUTOLOAD {
	use vars qw($AUTOLOAD);

	my $self = shift;

	return $self if ($AUTOLOAD =~ m/DESTROY/);

	my ($func) = ($AUTOLOAD =~ m/Mail::Log::Postfix::LogEntry::[A-Za-z0-9_]+::([a-zA-Z0-9]+)/);

	if($func && defined $self->{$func}) {
		return $self->{$func};
	}

	return $self;
}

1;

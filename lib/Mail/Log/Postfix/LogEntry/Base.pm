package Mail::Log::Postfix::LogEntry::Base;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my $that = shift;
	my $proto = ref($that) || $that;
	my $self = { @_ };

	bless($self, $proto);

	return $self;
}

sub type {
	my $self = shift;
	if(!$self->{'__data'}->[5]) {
		return 'line';
	}
	return $self->{'__data'}->[7];
}

sub queue_id {
	my $self = shift;
	return $self->{'__data'}->[6];
}

sub set_data {
	my $self = shift;
	@{$self->{'__data'}} = @_;
}

sub date {
	my $self = shift;
	return $self->{'__data'}->[0];
}

sub AUTOLOAD {
	use vars qw($AUTOLOAD);

	my $self = shift;

	return $self if ($AUTOLOAD =~ m/DESTROY/);

	my ($func) = ($AUTOLOAD =~ m/Mail::Log::Postfix::LogEntry::[A-Za-z0-9_]+::([a-zA-Z0-9_]+)/);

	if($func && defined $self->{$func}) {
		return $self->{$func};
	}

	return $self;
}


1;

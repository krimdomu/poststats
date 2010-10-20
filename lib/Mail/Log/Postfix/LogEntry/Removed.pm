package Mail::Log::Postfix::LogEntry::Removed;

use strict;
use warnings;

use base qw(Mail::Log::Postfix::LogEntry::Base);

sub new {
	my $that = shift;
	my $proto = ref($that) || $that;
	my $self = { @_ };

	bless($self, $proto);

	return $self;
}

1;

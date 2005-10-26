package SLOOPS::Tut::Person ;
  
use base qw/Class::AutoAccess/ ; # for easy attribute access.

# SLOOPS PART

our $PERSIST = {
    fields => {
	'firstName' => undef , # DEFAULT type will be used in database.
	'lastName'  => undef     
	}  
} ;

# END OF SLOOPS PART 

sub new{
    my ($class) = @_ ; # A persistant class MUST implement a no parameters constructor !
    my $self = {
	'firstName' => undef ,
	'lastName'  => undef ,
	'non_perst' => undef  # This attribute will not be persistent !!
	};
    return bless $self, $class ;
}

1;

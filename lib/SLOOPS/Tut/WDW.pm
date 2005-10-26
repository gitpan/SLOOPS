package SLOOPS::Tut::WDW ;

use base qw/Class::AutoAccess/ ;
   
our $PERSIST = {
    'references' => 
    {
	'who' => 'SLOOPS::Tut::Person' ,
	'what' => 'SLOOPS::Tut::Vehicule' # Polymorphism support !!
	}
};


sub new{
    my ($class) = @_ ;
    
    my $self = {
	'who' => undef,
	'what' => undef
	};
    return bless $self, $class ;
}
1;

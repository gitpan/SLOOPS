package SLOOPS::Tut::Vehicule ;

use base qw/Class::AutoAccess/ ;

our $PERSIST = {
    'fields' => {
	'nbDoors' => [ 'INT' , 0 ], # Here we use the possibility to control how the attribut will be
	# stored and what is its default value
	'nbWheels' => [ 'INT' , 1 ] 
	},
	    'references' => {
		'owner' => 'SLOOPS::Tut::Person' # Owner will be a reference on a person !!
		} 
};

sub new{
    my ($class) = @_ ;
    my $self = {
	'nbDoors' => undef ,
	'nbWheels' => undef, 
	'owner' => undef 
	};
    return bless $self, $class ;
}

1;

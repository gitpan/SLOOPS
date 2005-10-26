package SLOOPS::Tut::Plane ;

use base qw/SLOOPS::Tut::Vehicule/ ;
 
our $PERSIST = {
    'base' => 'SLOOPS::Tut::Vehicule' ,
    'fields' => {
	'nbWings' => undef 
	}
};

sub new{
    my ($class) = @_ ;
    my $self = $class->SUPER::new();
    
    $self->nbWheels(3) ;
    $self->{'nbWings'} = undef ; # van, convertible , coupe ...
    
    return bless $self , $class ;
    
}

1;

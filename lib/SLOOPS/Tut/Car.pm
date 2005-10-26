package SLOOPS::Tut::Car ;

use base qw/SLOOPS::Tut::Vehicule/ ;
 
our $PERSIST = {
    'base' => 'SLOOPS::Tut::Vehicule' ,
    'fields' => {
	'body' => undef 
	}
};

sub new{
    my ($class) = @_ ;
    my $self = $class->SUPER::new();
    
    $self->nbWheels(4) ;
    $self->{'body'} = undef ; # van, convertible , coupe ...
    
    return bless $self , $class ;
    
}

1;

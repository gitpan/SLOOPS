#! /usr/bin/perl 
use lib 'lib' ;

# INIT
use DBI ;

use SLOOPS::Factory { debug => 0 } ;
use SLOOPS::SchemaGenerator { debug => 0 };
use SLOOPS::DbDriverMySQL ;

#
# ADAPT THIS TO YOUR MYSQL DATABASE
#  
# CONNECTING TO DB
my $dbDriver = SLOOPS::DbDriverMySQL->new();
     my $dbh  = DBI->connect('dbi:mysql:test_perst', 'perlu', 'perl',
			     { RaiseError => 1, AutoCommit => 0 }) || die "No connect : $!";

$dbDriver->dbh($dbh);

my $g = SLOOPS::SchemaGenerator->instance();
$g->dbDriver($dbDriver);

SLOOPS::Factory->instance()->dbDriver($dbDriver);
# END OF INIT

# REGISTERING CLASSES
# Register the class(es) to handle.
$g->addClass('SLOOPS::Tut::Person');
$g->addClass('SLOOPS::Tut::Car');
$g->addClass('SLOOPS::Tut::Plane');
$g->addClass('SLOOPS::Tut::WDW');


$f = SLOOPS::Factory->instance();

my $p = SLOOPS::Tut::Person->new();
$p->firstName('John');
$p->lastName('Doe');
$f->saveObject($p) ;

my $p2 = $f->findOrCreate('SLOOPS::Tut::Person' ,
			  { 'firstName' => [ '=' , 'Bruce' ],
			    'lastName'  => [ '=' , 'Wayne' ]
			    });

my $c = $f->findOrCreate('SLOOPS::Tut::Car' , 
			 {
			     'nbDoors' => [ '=' , 2 ],
			     'nbWheels' => [ '=' , 4 ],
			     'owner' => $p2 ,
			     'body' => [ '=' , 'batcar' ]
			     });

my $p = $f->findOrCreate('SLOOPS::Tut::Plane' , 
			 {
			     'nbDoors' => [ '=' , 1 ],
			     'nbWheels' => [ '=' , 3 ],
			     'owner' =>  $f->findOrCreate('SLOOPS::Tut::Person' ,
							  { 'firstName' => [ '=' , 'Pete' ],
							    'lastName'  => [ '=' , 'Mitchell' ]
							    })
				 
				 ,
				 'nbWings' => [ '=' , 2 ]
			     });



my $vehicules = $f->seekObjects('SLOOPS::Tut::Vehicule', {
    'nbDoors' => [ '>' , 0 ] });

foreach my $v ( @$vehicules ){
    print 'Type: '.ref($v)."\n";  # CLASS POLYMORPHISM !!
    print 'Owner: '.$v->owner_O()->firstName() ." ".
	$v->owner_O()->lastName()."\n" ; # Object composition.
}

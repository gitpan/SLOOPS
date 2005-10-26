#!perl -T

use Test::More tests => 8 ;

BEGIN {
	use_ok( 'SLOOPS' );
        use_ok( 'SLOOPS::SchemaGenerator');
        use_ok( 'SLOOPS::Factory');
        use_ok( 'SLOOPS::Tut::Person');
        use_ok( 'SLOOPS::Tut::Vehicule');
        use_ok( 'SLOOPS::Tut::Car');
        use_ok( 'SLOOPS::Tut::Plane');
        use_ok( 'SLOOPS::Tut::WDW');

}

diag( "Testing SLOOPS $SLOOPS::VERSION, Perl $], $^X" );

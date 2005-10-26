#! /usr/bin/perl

use lib 'lib';

# INIT
use DBI ;

use SLOOPS::Factory { debug => 0 } ;
use SLOOPS::SchemaGenerator { debug => 0 };
use SLOOPS::DbDriverMySQL ;
 

#
#
#    PLEASE SET THAT ACCORDING TO YOUR MYSQL DATABASE !!!
#     
# 
# CONNECTING TO DB
my $dbDriver = SLOOPS::DbDriverMySQL->new();
     my $dbh  = DBI->connect('dbi:mysql:test_perst', 'perlu', 'perl',
			     { RaiseError => 1, AutoCommit => 0 }) || die "No connect : $!";
##
#
#
#



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


# THIS IS THE IMPLEMENTATION OF THE SCHEMA !!
$g->updateSchema(1); 


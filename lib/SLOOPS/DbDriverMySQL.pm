package SLOOPS::DbDriverMySQL ;

use base qw/Class::AutoAccess/ ;

sub new{
    my ($class) = @_ ;
    my $self = {
	'dbh' => undef ,
	'defaultType' => 'VARCHAR(255)',
	'defaultValue' => '' ,
	'uniqKeyDecl' => 'BIGINT UNSIGNED PRIMARY KEY',
	'referenceType' => 'BIGINT UNSIGNED' ,
	'String' => 'VARCHAR(255)' ,
	'MaxLength' => 255 
	};
    
    bless $self, $class ;
    return $self ;
}

sub lastInsertId{
    my ($self) = @_ ;
    #print "CALLING LAST INSERT ID !\n";
    return $self->dbh()->{'mysql_insertid'};
}

sub autoIncrement{
    my ($self, $table , $column ) = @_ ;
    #return "ALTER TABLE ".$table AUTO_INCREMENT = 100 
    return "AUTO_INCREMENT" ;
}


1;

package SLOOPS::SchemaGenerator ;

use base qw/Class::AutoAccess/ ;
use Carp;
use strict ;

my $instance = SLOOPS::SchemaGenerator->new();

my $debug = 0 ;

sub import{
    #my $callerPack = caller ;
    my ($class, $options) = @_ ;
    if(  ! defined $debug ){
    	$debug = $options->{'debug'} || 0 ;
    }
    print "\n\nDebug option : $debug \n\n" if ($debug);
}



sub instance{
    return $instance ;
}


sub new{
    my ($class) = @_ ;
    return bless {
	'classes' => {},
	'dbDriver' => undef 
    }, $class ;
}

sub dbh{
	my ($self, $dbh ) = @_ ;
	if( defined $dbh ) {
		$self->dbDriver()->dbh($dbh);
	}
	return $self->dbDriver()->dbh();
}



=head2 addClass

Adds a class and all its surclasses into this generator.
Sets the default values of PERSIST hash is they miss.

=cut

sub addClass{
    my ($self, $className) = @_ ;
    
    no strict 'refs' ;
    
    # Try to require $className ;
    eval "require $className ";
    if( $@ ){
    	confess("Cannot find class $className : $@");
    }
    
    my $hash = ${"$className".'::PERSIST'} ;
    use strict 'refs';
    if( ! defined $hash ){
	confess  "Class $className cannot persist";
    }
    
    # Storing reference. Redondancy is avoid by the hash nature of the storage.
    if( defined $self->classes()->{$className} ){
	# Allready stored .
	return ;
    }
    print "Adding class $className\n" if($debug);
    $self->classes()->{$className} = $hash ;
    
    $self->setDefaults($className, $hash );
    
    # Storing base if neccessary.
    if ( $hash->{'base'} ){
	$self->addClass($hash->{'base'});
    }
    
    # Generating sql.
    $self->classes()->{$className}->{'sql'} = $self->generateSql($className, $hash);

    # Generating methods for references
    if( $hash->{'references'} ){
	$self->generateReferenceMethods($className,$hash->{'references'});
    }
}

=head2 generateReferenceMethods

Generates the references methods in the class from the reference hash
of the class.

Let a reference called foo pointing to an Bar object in the persist hash.
The class MUST have a foo attribute that is dedicated to a Bar object.

This method will implement a foo method for the class that fetch the
perl object from the database on demand ( accessor behaviour)
Or just set the Foo object and check it is for the right class and save it if its not.


method template: for a reference named 'foo' to a Bar object.

sub foo_O{
    my ($self, $value ) = @_ ;
    if( $value ){
	if( ! $value->isa('Bar')){ confess("Bad class") ;}
	    $self->{'foo_Bar'} = $value ;
	    my $dbid = $value->{'_dbid_'} ;
	    if ( ! defined $dbid ){
		confess("Object $value is not saved");
	    }
	    $self->foo($dbid)
	 return $value ;
    }

    # if foo unset, got to fetch it.
    my $dbid = $self->foo();
    
    # If no dbid is set, theres no object to fetch
    if( ! defined $dbid ) { return undef ;}
    # Is the object is allready fetch
	if( defined $self->{'foo_O'} ) { return $self->{'foo_O'} ; }
  
    # really got to fetch
    return $self->{'foo_O'} = Factory->instance()->fetchObject('Bar',$dbid);

}


=cut

sub generateReferenceMethods{
    my ($self, $class , $refHash ) = @_ ;
    my @refs = keys %{$refHash} ;
    foreach my $ref ( @refs ){
	
	my $referencedClass = $refHash->{$ref};
	my $code = qq/
	    package  $class ;

	    sub $ref/.'_O'.qq/{
	       my (\$self, \$value ) = \@_ ;
               
               my \$dbid = undef ;
               if( \$value ){
	         if( ! \$value->isa('$referencedClass')){ Carp::confess(/."'Bad class :'".qq/.ref(\$value).' instead of $referencedClass') ;}
	         \$self->{'/.$ref.qq/_0'} = \$value ;
	         \$dbid = \$value->{'_dbid_'} ;
	         if ( ! defined \$dbid ){
		 Carp::confess(/.'"Object $value is not saved"'.qq/);
	       }
		 \$self->$ref(\$dbid);
		 \$self->{'$ref/.'_O'.qq/'} = \$value ;
	       return \$value ;
            }

            # if foo unset, got to fetch it.
           \$dbid = \$self->$ref();
    
           # If no dbid is set, theres no object to fetch
           if( ! defined \$dbid ) { return undef ;}
           # Is the object is allready fetch
	   if( defined \$self->{'$ref/.'_O'.qq/'} ) { return \$self->{'$ref/.'_O'.qq/'} ; }
  
           # really got to fetch
           return \$self->{'$ref/.'_O'.qq/'} = SLOOPS::Factory->instance()->fetchObject('$referencedClass',\$dbid);

          } /;

	eval $code ;
	if( $@ ) {
	    confess("Failed to implement method for reference $ref for class $class: $@");
	}
	print "Execute :: \n\n".$code."\n\n" if($debug);
    }
   
}


sub generateSql{
    my ($self, $class , $perst ) = @_ ;
    #$self->setDefaults($class,$perst) ;
    
    my $sql = 'CREATE TABLE '.$perst->{'table'}.' (';
    
    $sql .= ' dbid '.$self->dbDriver()->uniqKeyDecl().' ' ;
    if( ! defined $perst->{'base'} ){
	# This is root !
	$sql .= $self->dbDriver()->autoIncrement($perst->{'table'}, 'dbid');
	$sql .= ',';
	$sql .= 'dbRealClass '.$self->dbDriver()->String();
    }
    else{
	$sql .= ',CONSTRAINT FOREIGN KEY(dbid) REFERENCES '.$self->classes()->{$perst->{'base'}}->{'table'}.'(dbid)';
    }
    $sql .= ',' ;
    
    # Storing fields
    foreach my $field ( keys %{$perst->{'fields'}} ){
	$sql .= ' '.$field.' '.$perst->{'fields'}->{$field}->[0] ;
	$sql .= ' DEFAULT '.$self->dbh()->quote($perst->{'fields'}->{$field}->[1]).',';
    }


    # Storing references
    if ( $perst->{'references'} ) {
	foreach my $reference ( keys %{$perst->{'references'}} ){
	    my $referencedClass  = $perst->{'references'}->{$reference} ;
	    my $refHash = $self->classes()->{$referencedClass} ;
	    if( ! $refHash ){
		confess(qq/Class $referencedClass not registered in $self.
			Cannot be referenced by $class/);
	    }
	    
	    print "Referenced class: $referencedClass\n" if($debug);
	    $sql .= ' '.$reference.' '.$self->dbDriver()->referenceType().',';
	    $sql .= 'CONSTRAINT FOREIGN KEY ('.$reference.') REFERENCES '.$refHash->{'table'}.'(dbid),';
	}
    }
    chop( $sql );
    $sql .= ' )' ;
    print "SQL for $class: ".$sql ."\n" if($debug);
    return $sql ;
}

=head2 setDefaults

Sets default values for missing values in PERSIST hash for
a class.

Usage:
    my $class = .... ; # the persistent class name
    my $h = .... ; # The PERSIST HASH of the class $class;

    $sg->setDefault($class,$h);

=cut

sub setDefaults{
    my ($self, $class , $perst ) = @_ ;
    
    # Setting default table name.
    if( ! defined $perst->{'table'} ){
	my $table = $class;
	$table =~ s/::/_/g ;
	$table = lc $table ;
	$perst->{'table'} = $table."_auto" ;
    }
    
    if( ! defined $perst->{'fields'} ){
    	$perst->{'fields'} = {};
    }
    
    if( ! defined $perst->{'references'}){
    	$perst->{'references'} = {};
    }
    
    # Setting default datatypes.
    foreach my $field ( keys %{$perst->{'fields'}} ){
	if ( ! defined $perst->{'fields'}->{$field} ){
	    $perst->{'fields'}->{$field} = [ $self->dbDriver()->defaultType()  ,
					     $self->dbDriver()->defaultValue() ];
	}
    }
}


=head2 deleteSchema

Delete all the tables from the schema.

=cut

sub deleteSchema{
    my ($self ) = @_ ;
    my %persists = %{$self->classes()};
    foreach my $class ( keys %persists ){
	print "Deleting class $class \n" if($debug);
	my $table = $persists{$class}->{'table'} ;
	eval{
	    my $sql = 'DROP TABLE '.$table;
	    my $sth = $self->dbh()->prepare($sql);
	    $sth->execute();
	};
	if(  $@ ) {
	    warn("Cannot delete table $table : $@ ");
	}
    }
}

=head2 updateSchema

Implements the schema into the database.
If $override is true, call deleteSchema before.

usage:

    $sg->updateSchema([1]);

=cut

sub updateSchema{
    my ($self, $override ) = @_ ;
    
    if( $override ){
	$self->deleteSchema();
    }
    
    my %persists  =  %{$self->classes()}  ;
    # setting to 0 the saved flags.
    foreach my $class (keys %persists ){
	print "Setting not Saved for table " .$persists{$class}->{'table'}." , class: ".$class."\n" if($debug);
	$persists{$class}->{'saved'} = 0 ;
    } 
    
    # Then while it left tables, implement them.
    while( keys %persists ){
	my $classToSave = undef ;
	# Choose a good one.
	foreach my $class ( keys %persists ){
	    my $perst = $persists{$class};
	    if( ! defined $perst->{'base'} ){
		$classToSave = $class ;
		last ;
	    }
	    if( $self->classes()->{$perst->{'base'}}->{'saved'} ==  1 ){
		$classToSave = $class ;
		last ;
	    }
	    #confess("Algorithm failure");
	}
	if( ! defined $classToSave ){
	    confess("Algorithm failure");
	} 
	print "Considering ".$classToSave ."\n" if($debug);

	my $sql = $persists{$classToSave}->{'sql'} ;
	print "Executing ".$sql ."\n" if($debug);
	
	eval{
	    print "EXECUTING \n\n $sql \n\n" if($debug);
	    my $sth = $self->dbh()->prepare($sql);
	    $sth->execute();
	};
	if( $@ ){
	    carp("Implementation of class ".$classToSave." failed :".$@);
	}
	
	$persists{$classToSave}->{'saved'} =  1;
	
	delete $persists{$classToSave};
    }
    
    
}


1 ;

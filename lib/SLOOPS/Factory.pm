package SLOOPS::Factory ;

our $VERSION='0.01' ;

=head1 NAME

SLOOPS::Factory -  a general persistent object managing class.

=head1 DESCRIPTION

This is the main class to use this persistance framework.
Use it to seek objects, to save them, to delete them ...

=head1 AUTHOR

jerome@eteve.net

=head1 SYNOPSIS

use SLOOPS::Factory [ { debug => 0|1 } ];

my $f = SLOOPS::Factory->instance();

[ $f->setCache(0|1) ; ]

[ my $dbDriver = # A valid dbDriver ;
# Only one time needed for the life of the instance.
$f->dbDriver($dbDriver);
]

# Then use the methods..

=head1 METHODS

=cut


use strict ;
use Carp ;

use base qw/Class::AutoAccess/ ;

my $instance = SLOOPS::Factory->new();
my $debug = undef ;


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

=head2 setCache

Sets the cache on 1 /off 0
: $f->setCache(1);
  $f->setCache(0);

Setting the cache on allows to get always the same instance of object that old exactly the
same data when you fetch object.

=cut

sub setCache{
	my ($self, $on ) = @_ ;
	if( ! $on ){
		$self->cache()->clear() if ( $self->cache() );
		$self->{'cache'} = undef ;
		return ;
	}
	
	eval{
		require Cache::FastMemoryCache;
		require Cache::Cache ;
	};
	if( $@ ){
		carp("No Cache::FastMemoryCache available in system. Skipping");
		return ;
	}
	
	$self->cache(new Cache::FastMemoryCache({ 'namespace' => '-'.$self.'-' }));
	
}

sub new{
    my ($class) = @_ ;
    return bless {
	'dbDriver' => undef,
	'cache' => undef 
    } , $class ;
}

sub dbh{
	my ($self, $dbh ) = @_ ;
	if( defined $dbh ) {
		$self->dbDriver()->dbh($dbh);
	}
	return $self->dbDriver()->dbh();
}


=head2 createObject

Usage:

    my $o = $f->createObject("ObjectClass");

=cut

sub createObject{
    my ($self, $oclass ) = @_ ;
    
    return $oclass->new();
}

=head2 fetchObject

Fetch an object of class $oclass identified by $id from the database.

usage : 

    my $o = $f->fetchObject($oclass,$id);

=cut

sub fetchObject{
    my ($self, $oclass , $dbid ) = @_ ;
      
    print "Fetching $dbid for class $oclass\n" if ( $debug );
    #my $oclass = $self->getRealClass($oclass);
    # Getting real class for object $oclass with id .

    my $baseClass = $self->findBaseClass($oclass);
    
    if( $self->cache() ){
    	my $o = $self->cache()->get($oclass.'-'.$dbid);
    	if( $o ) {
    		return $o ;
    	}
    }
    
    no strict 'refs' ;
    my $hashBase = ${"$baseClass".'::PERSIST'};
    use strict 'refs';
    my $table = $hashBase->{'table'};
    # Retrieving real class
    my $sql = "SELECT dbRealClass FROM ".$table." WHERE dbid = ".$self->dbh()->quote($dbid);
    my $realClass = undef ;
    eval{
	my $sth = $self->dbh()->prepare($sql);
	$sth->execute();
	$realClass = $sth->fetch()->[0];
    };
    if( $@ ){
	confess("Cannot retrieve realClass for id $dbid, class $oclass: $@");
    }
    
    print "Base class is : $baseClass\n" if ($debug);
    print "Real class is : $realClass\n" if ($debug);
    
    my $o = $self->fetchObjectReal($realClass,$dbid);
    if( $self->cache() ){
    	$self->cache()->set($oclass.'-'.$dbid, $o , $Cache::Cache::EXPIRES_NEVER );
    }
    return $o ;
}

=head2 findBaseClass

Utility function.
Returns the base class of any persistent class.

=cut

sub findBaseClass{
    my( $self , $oclass ) = @_ ;
    no strict 'refs' ;
    my $hash = ${"$oclass".'::PERSIST'} ;
    use strict 'refs';
    if( ! defined $hash->{'base'} ) { return $oclass ;}
    return $self->findBaseClass($hash->{'base'});
    
}


=head2 fetchObjectReal

Fetch the object $dbid. $oclass is the real class of this object.

=cut

sub fetchObjectReal{
    my ($self, $oclass , $dbid , $o ) = @_ ;
  
    $o ||= $oclass->new();
    
    # Set $o attributes from this table;
    no strict 'refs' ;
    my $hash = ${"$oclass".'::PERSIST'} ;
    use strict 'refs';
    my $table = $hash->{'table'} ;
    if( ! defined $table ){ confess("No table defined for class $oclass") ; }

    my $sql = 'SELECT ';
    
    my @fields = keys %{$hash->{'fields'} || {} }  ;
    my @refs   = keys %{$hash->{'references'} || {}  };
    
    foreach my $field ( @fields ){
	$sql .= $field.',';
    }
    foreach my $ref ( @refs ){
	$sql .= $ref.',' ;
    }
    chop($sql) ;
    $sql .= ' FROM '.$table.' WHERE dbid = '.$self->dbh()->quote($dbid);

    my @row = () ;
    print "Exec: $sql\n" if ($debug);
    eval{
	my $sth = $self->dbh()->prepare($sql);
	$sth->execute();
	@row = $sth->fetchrow_array()
	};
    if ( $@ ) {
	confess("SQL ERROR : $@");
    }
    if( ! @row ){
	confess("No row with id = $dbid for class $oclass");
    }
    
    my $fielditem = 0 ;
    foreach my $field ( @fields){
	$o->$field($row[$fielditem]);
	$fielditem ++ ;
    }

    foreach my $ref ( @refs ){
	$o->$ref($row[$fielditem]);
	$fielditem++ ;
    }

    $o->{'_dbid_'} = $dbid ;
    
    # Calling recursively.
    if( $hash->{'base'} ){
	$self->fetchObjectReal($hash->{'base'} , $dbid , $o );
    }

    return $o ;
}

=head2 saveObject

Stores the object in the database and add an _dbid_ to it.
If _dbid_ is allready set, redirect to syncObject .

Returns the object database id (_dbid_)

SQL equiv: insert.

=cut

sub saveObject{
    my ($self, $o ) = @_ ;
    if( exists $o->{'_dbid_'} ){
	return $self->syncObject($o) ;
    }
    
    # Do a simple insert, get the new id and sync the object.
   
    my $oclass = ref ( $o ) ;
    
    no strict 'refs' ;
    
    my $hash = ${"$oclass".'::PERSIST'} ;
    use strict 'refs';
    
    if ( ! defined $hash ){
	confess("Class $oclass is not set to be persistant");
    }

    $o->{'_dbid_'} = $self->createTuple($oclass); # generated id.
    return $self->syncObject($o);
}


sub createTuple{
    my ($self , $class , $realclass ) = @_ ;
    
    $realclass ||= $class ;
    
    no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
	use strict 'refs';

    my $table = $persist->{'table'} ;
    
    my $id = undef ;
    my $sql = undef ;
    
    if( defined $persist->{'base'} ){
	$id = $self->createTuple($persist->{'base'}, $realclass );
    }
    
    if( $id ){
	# It is not a base class.
	$sql = 'INSERT INTO '.$table.' (dbid) values('.$id.')';
	print "Exec with id : $sql\n" if($debug);
	eval{
	    my $sth = $self->dbh()->prepare($sql);
	    $sth->execute();
	    #$id = $self->dbDriver()->lastInsertId($table);
	};
	if( $@ ){
	    confess("Insert failed: $@");
	}
	
	return $id ;
    }
    
    # Insert into table $table
    # a void tuple. i.e base class.
    #$sql = 'INSERT INTO '.$table.'(dbRealClass) values ('.$self->dbh()->quote($realClass).')' ;
    # No need of this since it s done in the updateTuple method.
    
    $sql = 'INSERT INTO '.$table.' values ()';
    print "Exec: $sql\n" if ($debug);
    eval{
	my $sth = $self->dbh()->prepare($sql);
	$sth->execute();
    $id = $self->dbDriver()->lastInsertId($table);

    };
    if( $@ ){
	confess("Insert failed: $@");
    }
    
    return $id;
}


=head2 saveObject

Synchronize the object value with the database.
    Returns the object database id ( _dbid_ )  

SQL equiv: update.

=cut

sub syncObject{
    my ($self , $o ) = @_ ;
    if( ! exists $o->{'_dbid_'} ){
	confess("Cannot sync object $o since its not saved yet");
    }
    my $oclass = ref( $o );
    no strict 'refs' ;
    my $persist = ${"$oclass".'::PERSIST'} ;
    use strict 'refs';
    if(  ! defined $persist){
	confess("Class $oclass is not set to be persistant");
    }
    
    $self->updateTuple($o,$oclass);
    return $o->{'_dbid_'} ;
}

sub updateTuple{
    my ($self , $o , $class , $realclass ) = @_ ;
    
    $realclass ||= $class ;

    no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
    use strict 'refs';

    my $table = $persist->{'table'} ;
    if( defined $persist->{'base'} ){
	$self->updateTuple($o , $persist->{'base'}, $realclass );
    }
    
    my $sql = 'UPDATE '.$table.' SET' ;
    
    if( ! defined $persist->{'base'} ){
	# Base class, got to store the real class.
	$sql .= ' dbRealClass = '.$self->dbh()->quote($realclass).',';
    }

    my @fields = keys ( %{$persist->{'fields'}} );
    
    foreach my $field ( @fields ) {
	$sql  .= ' '.$field.' = '.$self->dbh()->quote($o->$field()).',';
    }

    # references
    my @refs = keys ( %{$persist->{'references'} || {} } );
    foreach my $refs ( @refs ){
	$sql .= ' '.$refs.' = '.$self->dbh()->quote($o->$refs()).',' ;
    }

    chop($sql);
    
    $sql .= ' WHERE dbid = '.$self->dbh()->quote($o->{'_dbid_'}) ;
    
    print 'Exec: '.$sql."\n" if($debug);
    eval{
	my $sth = $self->dbh()->prepare($sql);
	$sth->execute();
    };
    if( $@ ){
	confess("Update of table ".$table." failed: ".$@);
    }
    
}


=head3 deleteObject

Removes the object from the database.

Empty the object from all database properties, turning it into
a plain perl-space object.


SQL equiv: delete

=cut

sub deleteObject{
    my ($self , $o ) = @_ ;
    if( ! exists $o->{'_dbid_'} ){
	confess("Object $o is not persistent in database. Cannot delete");
    }
	
	my $class = ref($o);
	my $id =  $o->_dbid_();
	
	print "Deleting $o\n" if($debug);
	
	$self->deleteTuple($class,$id);
	
    delete $o->{'_dbid_'} ;
}

sub deleteTuple{
	my ($self,$class,$id) = @_ ;
	
	no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
    use strict 'refs';
	
	my $table = $persist->{'table'} || confess("No table defined for class $class");
	
	my $sql = 'DELETE FROM '.$table.' WHERE dbid = '.$self->dbh()->quote($id) ;
	eval{
		my $sth = $self->dbh()->prepare($sql);
		$sth->execute();
	};
	if( $@ ){
		confess("Cannot delete tuple $id from table $table: $@");
	}
	
	# Remove super tuple.
	my $base = $persist->{'base'} ;
	if( defined $base ){
		$self->deleteTuple($base,$id);
	}
	
}

=head2 find

Returns the only instance found with the given constraints and existence.
Returns Undef if none found.
Dies if more than one instance is found.

Usage:

my $contraints = { ... } ; # See seekIds for syntax
my $existences = { ... } ; # See seekIds for syntax

my $o = $f->find($class,$constraints,$existences);


=cut

sub find{
	my ($self , $class , $constraints , $existence ) = @_ ;
	$constraints ||= {};
	$existence   ||= {} ;
	my @ids = @{$self->seekIds($class,$constraints,$existence)};
	
	if( @ids > 1 ){
		my $msg = "More than one object of class $class fullfills the constraints:";
		while ( my ($key , $value ) = each %{$constraints} ){
			$msg .= ' '.$key.' '.$value->[0].' '.$value->[1].' ,';
		}
		confess($msg);
	}
	
	if( @ids  == 1 ){
		print "One object found !\n" if ($debug );
		return $self->fetchObject($class,$ids[0]);
	}
	return undef ;
}


=head2 findOrCreate

Returns a newly created object with the equality constraints and the reference
constraints used to initiate the object if it doesn't exists in the database.

Returns the object from the database if it's allready there.

Dies if more than one object fullfills the given constraints.

Usage:

my $contraints = { ... } ; # See seekIds for syntax
my $existences = { ... } ; # See seekIds for syntax

my $o = $f->findOrCreate($class,$constraints,$existences);

=cut

sub findOrCreate{
	my ($self, $class, $constraints , $existence ) = @_ ;
	$constraints ||= {};
	$existence   ||= {} ;

	# If object is found, return !!
	my $o = $self->find($class,$constraints , $existence );
	
	if ( defined $o ){
		return $o ;
	}
	
	print "Constructing object\n" if($debug);
	# Ok, object does not exists in the database.
	$o = $self->createObject($class);
	# Set the value from the equality constraints.
	
	while( my ($key , $value ) = each %{$constraints} ){
		# If a value is set ..
		if(  ref($value) eq 'ARRAY' && $value->[0] eq '=' ){
			$o->$key($value->[1]);
			next ;
		}
		# If this is a reference on an object ..
		if( ref($value) ){
			my $acc = $key.'_O';
			$o->$acc($value);
		}
	}
	
	# Save and return  !
	$self->saveObject($o);
	return $o ;
	
}

=head2 seekObjects

Same usage as seekIds, but return a set of allready constructed objects.

=cut

sub seekObjects{
    my ($self, $class, $constraints, $existence)   = @_  ;
    my $ids = $self->seekIds($class,$constraints, $existence );
    
    my @res = () ;
    foreach my $id ( @{$ids}){
	push @res , $self->fetchObject($class,$id);
    }
    return \@res ;
}


=head2 seekIds

Returns a collection of id of object for the class $class in the database.
These object matches the constraints.

Contraints can concern super class attributes and references.

usage :

    my $constraint = {
	'field1' => [ $operator , $value ],
	...
	'reference1' => $referencedObject
    };

my $existence = {
    'field1' => 'exist' , # Field is set
    'field2' => undef ,   # field is not set
    'reference1' => 'exist' , # idem
    'reference2' => undef # idem
    ...
    };
 
    my $ids = $self->seekIds('ClassName' , $constraint , $existence );



=cut

sub seekIds{
    my ($self, $class , $constraints , $existence ) = @_ ;
    
    $constraints ||= {};
    $existence   ||= {};
	
    # Lets construct a query .
    no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
    use strict 'refs';
    
    my $dbdriver = $self->dbDriver();
    
    my $table = $persist->{'table'} || confess("No table defined for class $class");
    my $fields = $persist->{'fields'} || {};
    my $references = $persist->{'references'} || {};

    my $sql = 'SELECT dbid FROM '.$table.' WHERE ';
    
    # Constraints.
     my $mustSuper = 0 ;
    
    my $constraintsRest = {} ;
    while (my ($key,$value) = each %{$constraints}) {
        # if $key in fields, value must be an array [ operator , value ]
	# if $key in references , value must be an object with _dbid_() setted.
	if( defined $fields->{$key} ){
	    my $operator = $value->[0] || confess ("No operator defined for $key");
	    if (! defined  $value->[1] ){
	    	confess ("No value defined for $key");
	    }
	    my $cmpvalue = $value->[1] ;
	    # substr EXPR,OFFSET,LONGUEUR
	    if ( (length ($cmpvalue) > $dbdriver->MaxLength()) &&
	    	( $fields->{$key}->[0] eq $dbdriver->String()) ){
	    	carp("Truncating value : $cmpvalue");
	    	$cmpvalue = substr $cmpvalue , 0 , $dbdriver->MaxLength() ;
	    } 
	    $sql .= $key.' '.$operator.' '.$self->dbh()->quote($cmpvalue).' AND ';
	    next;
	}
	
	
		if( defined $references->{$key} ){
	    	my $o = $value ;
		if( ! defined $o ){
		    confess("Given object for key $key is not defined");
		}
	    	eval{
			my $dbid = $o->_dbid_();
			$sql .= $key.' = '.$self->dbh()->quote($dbid).' AND ';
	    };
	    if ( $@ ){ confess("Considered key: $key .  No dbid for given object $o : $@ ");}
	    	next ;
		}
	#confess("Unknown $key as attribute or reference for $class");
		$constraintsRest->{$key} = $value ;
		$mustSuper = 1 ;
    }
    
    # Existence
   
    my $existRest = {};
    while( my ($key,$value) = each %{$existence} ){
	
		if( defined $fields->{$key} || defined $references->{$key} ){
	
			$sql .= ' '.$key.' ';
			if( $value ){
	    		$sql .= ' IS NOT NULL ';
			}
			else{
	    		$sql .= ' IS NULL ';
			}
			$sql .= ' AND ';
			next;
    	}
    	$existRest->{$key} = $value ;
    	$mustSuper = 1 ;
    }
    $sql .= ' 1 ';
    print "Exec :$sql\n" if($debug);
    my @res = () ;
    eval{
	my $sth = $self->dbh()->prepare($sql);
	$sth->execute();
	while( my $tuple = $sth->fetch() ){
	    push @res ,  $tuple->[0];
	}
    };
    if( $@ ){
	confess("Cannot execute $sql : $@");
    }
    
    # If something is here in contraintsRest or existRest, go to seek ids in
    # super class. If no super class, then its an error
    # The res should be the intersection of the returns ids.
    if( $mustSuper ){
    	my $base = $persist->{'base'} || confess("Must have a super class for $class since it has extra contraints");
    	my $superRes = $self->seekIds($base,$constraintsRest,$existRest);
    	my ($onlya, $onlyb, $both, $either ) = _listy($superRes , \@res);
    	@res = @{$both || [] };
    }
    
    return \@res ;
}

=head2 findDistinctFieldsFrom

Finds the distinct values of the given $field in the instances
of the $class that match the constraints $constraints and $existence
like in seekIds .

If $field is a name of reference instead of a plain field, it returns the collection
of corresponding object.

Usage:

my $ObjsOrScalars = $f->findDistinctFieldsFrom($field , $class , $constraints , $existence );
		
	

=cut

sub findDistinctFieldsFrom{
	my ($self, $field, $class, @rest ) = @_ ;
	
	# Find objects
	my $objs = $self->seekObjects($class,@rest);
	
	# Lets construct a query .
    no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
    use strict 'refs';
	
	# Then unique of asked field.
	my %uniq = ();
	foreach my $o (@{$objs}) {
		$uniq{$o->$field()} = 1 ;
	}
	
	my @values = sort keys %uniq;
	
	if( defined $persist->{'references'}->{$field} ){
		# Fetch objects from the right class.
		my $refClass = $persist->{'references'}->{$field} ;
		my @objs = ();
		foreach my $v ( @values ){
			push @objs , $self->fetchObject($refClass,$v);
		}
		@values = @objs ;
	}
	
	return \@values ;
}

sub nbInstances{
	my ($self, $class ) = @_ ;
	
	no strict 'refs' ;
    my $persist = ${"$class".'::PERSIST'} ;
    use strict 'refs';
	
	my $table = $persist->{'table'} || confess("No table for class $class");
	
	my $sql = "SELECT COUNT(*) FROM ".$table ;
	my $count = undef ;
	eval {
		my $sth = $self->dbh()->prepare($sql);
		$sth->execute() ;
		$count = $sth->fetch()->[0];
	};
	if( $@ ){
		confess ("Database error: ".$@);
	}
	
	return $count ;
}

sub _listy {
    my %tmp1;
    for (0..1) {
	for my $k (@{$_[$_]}) {
	    $tmp1{$k} .= $_;
	}
    }
    my %tmp2;
    while (my($k, $v) = each %tmp1) {
	push @{$tmp2{$v}}, $k;
    }
    return @tmp2{"0", "1", "01"}, [keys %tmp1];
}



1;

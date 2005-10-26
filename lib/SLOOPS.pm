package SLOOPS;

use warnings;
use strict;

=head1 NAME

SLOOPS - Simple, Light, Object Oriented Persistence System .

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

SLOOPS is a lightweight Object Oriented persistence system. 

If you want to follow the tutorial, uncompress the distribution from command line !

It has been designed with simplicity and reliability in mind. So you should expect:

- VERY EASY AND QUICK implementation of your own datamodel.
- VERY EASY retrieving of your data.
- Some limitations that are negligable for 90% of cases !

It has been tested in production environment for months, so you can relie on it !

It allows to make objects persistents with just
a few lines of declarative code. It supports:

 - Inheritance
 - Class polymorphism.
 - Scalar attributes ( can be Object ! )
 - SQL Free queries !
 - MySQL database ( other ones in the future ).
 - Optionnal caching based on Cache::FastMemoryCache .

It doesn't support :

 - nonscalar attributes. So you have to do helper objects to support n-n relations . Is it so bad ?
 - transaction . That's a serious issue. Will be implemented with other database support !
 


=head1 TUTORIAL

Here, you'll learn how to use SLOOPS to implement your own persistent datamodel.

=head1 Datamodel.
  
For the purpose of this tutorial, we'll use a very simple datamodel. It is composed of Vehicules
which can be Cars or Planes , Persons who owns vehicules. A vehicule can be driven by: its owner but
also by other persons.

So we got:
   Vehicule - own by -> one person.
   Car - Is a -> Vehicule     ( inheritance )
   Plane - Is a -> Vehicule   ( inheritance )
   Vehicule - driven by -> several persons
   Person   - drives -> several vehicules    Here we'll need a helper class to represent this n-n relation.

 Attributes of classes are obvious !

=head2 Implementation.

First, let's implement the Person class !

  package SLOOPS::Tut::Person ;
  
  use base qw/Class::AutoAccess/ ; # for easy attribute access.

  # SLOOPS PART
 
  our $PERSIST = {
    fields => {
         'firstName' => undef , # DEFAULT type will be used in database.
         'lastName'  => undef     
        }  
  } ;

  # END OF SLOOPS PART 
 
  sub new{
      my ($class) = @_ ; # A persistant class MUST implement a no parameters constructor !
      my $self = {
	  'firstName' => undef ,
	  'lastName'  => undef ,
          'non_perst' => undef  # This attribute will not be persistent !!
      };
      return bless $self, $class ;
  }
   
  1;

So you understood how it works !

All you have to do to turn a class persistent is :
 
 - implement a void parameter contructor named 'new' .
 - set the $PERSIST global variable of your class to indicate what to persist !

Now, we're ready to implement our Vehicule class !

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

Here is a new concept:

The reference . It is used to make persistent the composition of object.
In this case, it means the vehicule will hold a reference on its owner object. And that will be persistent!

Ok now let's implement our subclasses of Vehicules (Car and Plane):

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

Just say 'base' => 'SLOOPS::Tut::Vehicule' , add the added field and that's all !!

Write Plane by yourself !! (or pick the code in SLOOPS/Tut directory ..)

To end with datamodel, let's implement the WhoDrivesWhat class (remember our n-n relation ! ).

    package SLOOPS::Tut::WDW ;
    
    use base qw/Class::AutoAccess/ ;
   
    our $PERSIST = {
       'references' => 
          {
            'who' => 'SLOOPS::Tut::Person' ,
            'what' => 'SLOOPS::Tut::Vehicule' # Polymorphism support !!
    }};

    sub new{
	my ($class) = @_ ;

	my $self = {
	    'who' => undef,
	    'what' => undef
	};
	return bless $self, $class ;
    }    
    1;

Ok, that's all for our Datamodel. As you see, you need a very few lines to implement each class.
Almost each line of code contains usefull information.
Implementing and testing an object datamodel is a matter of hours instead of days !

=head2 MODEL DEPLOYMENT

Now, our model is ok, we need to deploy it in a database in order to be able to use it.
All you have to do is to connect the system to the database. Tell him what class are persistent, and
ask for deployement.

The following code should go in the deployment script of your application:

 # INIT
 use DBI ;

 use SLOOPS::Factory { debug => 0 } ;
 use SLOOPS::SchemaGenerator { debug => 0 };
 use SLOOPS::DbDriverMySQL ;
  
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
 
 # THIS IS THE IMPLEMENTATION OF THE SCHEMA !!
 $g->updateSchema(1); 

That's all for model deployment !
Note that the code between #INIT and #END OF INIT have to be used ONCE in the init phase
of your application.

You can find this deployement script into the deployTut.pl script of the distribution.

=head2 USING YOUR SLOOPS model implementation.

In this section, we'll see how to use SLOOPS to make new instance of objects, to retrieve
instances and to navigate throu references. We'll only give simple use.

See SLOOPS::Factory documentation for complete doc about all possible functions you can use
to interact with your model.

Let's say we got $f, a factory instance (remember to run the init code first !):

 $f = SLOOPS::Factory->instance();

Now, we can create a person object !

 my $p = SLOOPS::Tut::Person->new();
 $p->firstName('John');
 $p->lastName('Doe');

To make it persistant:
 
 $f->saveObject($p) ;


You also directly create (or find if it allready exists) a person object which is allready persistent:

 my $p2 = $f->findOrCreate('SLOOPS::Tut::Person' ,
                           { 'firstName' => [ '=' , 'Bruce' ],
                             'lastName'  => [ '=' , 'Wayne' ]
                           });

This is one of my favorite features !

Now, let's create a car that belongs to bruce wayne !

 my $c = $f->findOrCreate('SLOOPS::Tut::Car' , 
                    {
                      'nbDoors' => [ '=' , 2 ],
                      'nbWheels' => [ '=' , 4 ],
                      'owner' => $p2 ,
                      'body' => [ '=' , 'batcar' ]
                    });

We can also cascade many findOrCreate to create at the same time the vehicule and the owner...


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
 

These are the two main possibilities to create object.

To retrieve them, there's a lot of possibilities. Let's stay simple:

    my $vehicules = $f->seekObjects('SLOOPS::Tut::Vehicule', {
    'nbDoors' => [ '>' , 0 ] });
 
    foreach my $v ( @$vehicules ){
        print 'Type: '.ref($v)."\n";  # CLASS POLYMORPHISM !!
        print 'Owner: '.$v->owner_O()->firstName() ."\n" ; # Object composition.
    }

The important point is the 'owner_O' method of the retrieved vehicule.
This is an auto generated method that allows you to access the object references by
the attribute 'owner' of the vehicule class.

These method 'attribute'_O are automatically generated for all reference attributes !
So you can use them to access object directly without making any other request.

This usage code is available in the useTut.pl script given in the distribution !


There's many things you can do with SLOOPS. To see all possibility, please refer to 
the SLOOPS::Factory documentation !!


=head1 REFERENCE

=head2 SYNTAX of $PERSIST


  Persist should look like that :

  $PERSIST = {
    'base' => 'AObjectClass' , # OPTIONNAL 
    fields => {                # OPTIONNAL
       'f1' => undef ,            # DEFAULT SQL TYPE AND DEFAULT VALUE GIVEN BY SQL DRIVER
       'f2' => [ 'NUMBER', 0 ] ,# CHOOSEN TYPE AND CHOOSEN DEFAULT
       ....
    },
    references => {            # OPTIONNAL
        'ref1' => 'AnObjectClass', # A Reference on another object of given class or subclasses of it !
        ...
    }
};




=head1 AUTHOR

Jerome Eteve, C<< <jerome@eteve.net> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-sloops@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SLOOPS>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2005 Jerome Eteve, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SLOOPS

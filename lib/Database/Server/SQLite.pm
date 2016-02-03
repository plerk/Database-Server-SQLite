use strict;
use warnings;
use 5.020;
use Database::Server;

package Database::Server::SQLite {

  # ABSTRACT: Interface for SQLite faux server instance
  
=head1 SYNOPSIS

 use Database::Server::SQLite;
 
 my $server = Database::Server::SQLite->new(
   data => "/tmp/dataroot",
 );
 
 $server->init;
 $server->start;
 $server->stop;
 
 if($server->is_up)
 {
   say "server is up";
 }
 else
 {
   say "server is down";
 }

=head1 DESCRIPTION

This class provides a simple interface for creating, starting, stopping,
restarting and reloading SQLite faux instances.

=cut

  use Moose;
  use MooseX::Types::Path::Class qw( File Dir );
  use File::Which qw( which );
  use Carp qw( croak );
  use File::Temp qw( tempfile );
  use namespace::autoclean;

  with 'Database::Server::Role::Server';

  has sqlite3 => (
    is      => 'ro',
    isa     => File,
    coerce  => 1,
    lazy    => 1,
    default => sub {
      which 'sqlite3';
    },
  );

=head2 data

 my $dir = $server->data;

The data directory root for the server.  This
attribute is required.

=cut

  has data => (
    is       => 'ro',
    isa      => Dir,
    coerce  => 1,
    required => 1,
  );
  
=head1 METHODS

=head2 create

 Database:Server::SQLite->create($root);

(class method)
Create, initialize a SQLite faux instance, rooted under C<$root>.  Returns
a hash reference which can be passed into C<new> to reconstitute the 
database faux instance.  Example:

 my $arg = Database::Server::SQLite->create("/tmp/foo");
 my $server = Database::Server::SQLite->new(%$arg);

=cut

  sub create
  {
    my(undef, $root) = @_;
    $root = Dir->coerce($root);
    my $data = $root->subdir( qw( var lib data sqlite ) );
    $_->mkpath(0, 0700) for ($data);
    
    my %args = ( data => $data->stringify );
    __PACKAGE__->new(%args)->init;
    \%args;
  }

=head2 init

 $server->init;

Initialize the SQLite faux instance.

=cut
  
  sub init
  {
    my($self) = @_;
    croak "@{[ $self->data ]} is not empty" if $self->data->children;
    $self->data->file('sqlite.sqlite')->touch;
    $self->good;
  }

=head2 start

 $server->start;

Starts the SQLite faux instance.

=cut

  sub start
  {
    shift->good;
  }

=head2 stop

 $server->stop;

Stops the SQLite faux instance.

=cut

  sub stop
  {
    shift->good;
  }

=head2 restart

 $server->restart;

Restarts the SQLite faux instance.

=cut

  sub restart
  {
    shift->good;
  }

=head2 is_up

 my $bool = $server->is_up;

Checks to see if the SQLite faux instance is up.
This is true, so long as the database has been initialized.

=cut

  sub is_up
  {
    my($self) = @_;
    !!(-d $self->data && -f $self->data->file('sqlite.sqlite'))
  }

  __PACKAGE__->meta->make_immutable;

=head2 list_databases

 my @names = $server->list_databases;

Returns a list of the databases on the SQLite faux instance.

=cut

  sub list_databases
  {
    my($self) = @_;
    map { s/\.sqlite$//r } grep /\.sqlite$/, map { $_->basename } grep { ! $_->is_dir } $self->data->children;
  }

=head2 create_database

 $server->create_database($dbname);

Create a new database with the given name.

=cut

  sub create_database
  {
    my($self, $dbname) = @_;
    croak "no database name provided" unless $dbname;
    my $file = $self->data->file("$dbname.sqlite");
    croak "database already exists" if -f $file;
    $file->touch;
    $self;
  }

=head2 drop_database

 $server->drop_database($dbname);

Drop the database with the given name.

=cut

  sub drop_database
  {
    my($self, $dbname) = @_;
    croak "no database name provided" unless $dbname;
    my $file = $self->data->file("$dbname.sqlite");
    croak "database does not exist" unless -f $file;
    $file->remove;
    $self;
  }

=head2 interactive_shell

 $server->interactive_shell($dbname);
 $server->interactive_shell;

Connect to the database using an interactive shell.

=cut

  sub interactive_shell
  {
    my($self, $dbname, %args) = @_;
    $dbname //= 'sqlite';
    my $file = $self->data->file("$dbname.sqlite");
    croak "Database $dbname does not exist" unless -f $file;
    $args{exec} ? exec $self->sqlite3, $file : $self->run($self->sqlite3, $file);
    $self;
  }

=head2 shell

 $server->shell($dbname, $sql, \@options);

Connect to the database using a non-interactive shell.

=over 4

=item C<$dbname>

The name of the database

=item C<$sql>

The SQL to execute.

=item C<\@options>

The C<sqlite3> options to use.

=back

=cut

  sub shell
  {
    my($self, $dbname, $sql, $options) = @_;
    $dbname  //= 'sqlite';
    $options //= [];
    
    my $file = $self->data->file("$dbname.sqlite");
    croak "Database $dbname does not exist" unless -f $file;

    my($fh, $filename) = tempfile("sqliteXXXX", SUFFIX => '.sql');
    print $fh $sql;
    close $fh;
    
    open STDIN, '<', $filename;
    
    my $ret = $self->run($self->sqlite3, $file, @$options);
    
    open STDIN, '<', '/dev/null';
    
    unlink $filename;
    
    $ret;
  }

=head2 dsn

 my $dsn = $server->dsn($driver, $dbname);
 my $dsn = $server->dsn($driver);
 my $dsn = $server->dsn;

Provide a DSN that can be fed into DBI to connect to the database using L<DBI>.  These drivers are supported: L<DBD::SQLite>.

=cut

  sub dsn
  {
    my($self, $driver, $dbname) = @_;
    $dbname //= 'sqlite';
    $driver //= 'SQLite';
    $driver =~ s/^DBD:://;
    croak "Do not know how to generate DNS for DBD::$driver" unless $driver eq 'SQLite';
    my $file = $self->data->file("$dbname.sqlite");
    croak "database $dbname does not exist" unless -f $file;
    "dbi:SQLite:dbname=$file";
  }

}

1;

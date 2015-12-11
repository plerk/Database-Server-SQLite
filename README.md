# Database::Server::SQLite [![Build Status](https://secure.travis-ci.org/plicease/Database-Server-SQLite.png)](http://travis-ci.org/plicease/Database-Server-SQLite)

Interface for SQLite faux server instance

# SYNOPSIS

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

# DESCRIPTION

This class provides a simple interface for creating, starting, stopping,
restarting and reloading SQLite faux instances.

## data

    my $dir = $server->data;

The data directory root for the server.  This
attribute is required.

# METHODS

## create

    Database:Server::SQLite->create($root);

(class method)
Create, initialize a SQLite faux instance, rooted under `$root`.  Returns
a hash reference which can be passed into `new` to reconstitute the 
database faux instance.  Example:

    my $arg = Database::Server::SQLite->create("/tmp/foo");
    my $server = Database::Server::SQLite->new(%$arg);

## init

    $server->init;

Initialize the SQLite faux instance.

## start

    $server->start;

Starts the SQLite faux instance.

## stop

    $server->stop;

Stops the SQLite faux instance.

## restart

    $server->restart;

Restarts the SQLite faux instance.

## is\_up

    my $bool = $server->is_up;

Checks to see if the SQLite faux instance is up.
This is true, so long as the database has been initialized.

## list\_databases

    my @names = $server->list_databases;

Returns a list of the databases on the SQLite faux instance.

## create\_database

    $server->create_database($dbname);

Create a new database with the given name.

## drop\_database

    $server->drop_database($dbname);

Drop the database with the given name.

## interactive\_shell

    $server->interactive_shell($dbname);
    $server->interactive_shell;

Connect to the database using an interactive shell.

## shell

    $server->shell($dbname, $sql, \@options);

Connect to the database using a non-interactive shell.

- `$dbname`

    The name of the database

- `$sql`

    The SQL to execute.

- `\@options`

    The `sqlite3` options to use.

## dsn

    my $dsn = $server->dsn($driver, $dbname);
    my $dsn = $server->dsn($driver);
    my $dsn = $server->dsn;

Provide a DSN that can be fed into DBI to connect to the database using [DBI](https://metacpan.org/pod/DBI).  These drivers are supported: [DBD::SQLite](https://metacpan.org/pod/DBD::SQLite).

# AUTHOR

Graham Ollis &lt;plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

use strict;
use warnings;
use Test::More tests => 2;
use Database::Server::SQLite;
use File::Temp qw( tempdir );
use Path::Class qw( dir );

subtest 'normal' => sub {
  plan tests => 9;
  
  my $data = dir( tempdir( CLEANUP => 1 ) );
  my $server = Database::Server::SQLite->new(
    data => $data,
  );
  isa_ok $server, 'Database::Server::SQLite';

  is $server->is_up, '', 'server is down before init';

  subtest init => sub {
    plan tests => 2;
    my $ret = eval { $server->init };
    is $@, '', 'creating server did not crash';
    ok $ret->is_success, 'init database';
  };

  is $server->is_up, 1, 'server is up after init';
  
  subtest start => sub {
    plan tests => 2;
    my $ret = eval { $server->start };
    is $@, '', 'start server did not crash';
    ok $ret->is_success, 'started database';
  };

  subtest 'create/drop/list' => sub {
    plan tests => 5;
  
    eval { $server->create_database('foo') };
    is $@, '', 'server.create_database';
    
    my %list = map { $_ => 1 } eval { $server->list_databases };
    is $@, '', 'server.list_databases';
    ok $list{foo}, 'database foo exists';
    
    note "databases:";
    note "  $_" for keys %list;
    
    eval { $server->drop_database('foo') };
    is $@, '', 'server.drop_database';
    
    %list = map { $_ => 1 } eval { $server->list_databases };
    ok !$list{foo}, 'database foo does not exist';
  
  };
  
  subtest 'shell/dsn' => sub {
  
    plan tests => 2;
  
    my $dbname = 'foo1';
    eval { $server->create_database($dbname) };
    diag $@ if $@;
    my $sql = q{
      CREATE TABLE bar (baz VARCHAR);
      INSERT INTO bar VALUES ('hi there');
    };
  
    eval { $server->shell($dbname, $sql, []) };
    is $@, '', 'server.shell';

    foreach my $driver (qw( SQLite ))
    {
      subtest "DBD::$driver" => sub {
        plan skip_all => "test requires DBD::$driver" unless eval qq{ use DBI; use DBD::$driver; 1 };
        plan tests => 2;
        my $dsn = eval { $server->dsn($driver, $dbname) };
        is $@, '', "server.dsn($driver, $dbname)";
        note "dsn=$dsn";
        my $value = eval {
          my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1, AutoCommit => 1 });
          my $sth = $dbh->prepare(q{ SELECT baz FROM bar });
          $sth->execute;
          $sth->fetchrow_hashref->{baz};
        };
        is $value, 'hi there', 'query good';
      };
    }
  
  };
  
  subtest dump => sub {
    plan tests => 6;
    $server->create_database('dumptest1');
    $server->shell('dumptest1', "CREATE TABLE foo (id int); INSERT INTO foo (id) VALUES (22);");

    my $dump = '';
    $server->dump('dumptest1', \$dump, data => 0, schema => 1);
    isnt $dump, '', 'there is a dump (schema only)';
    
    $server->create_database('dumptest_schema_only');
    $server->shell('dumptest_schema_only', $dump);
    
    $dump = '';
    $server->dump('dumptest1', \$dump, data => 1, schema => 1);
    isnt $dump, '', 'there is a dump (data only)';

    $server->create_database('dumptest_schema_and_data');
    $server->shell('dumptest_schema_and_data', $dump);
    
    my $dbh = eval {
      DBI->connect($server->dsn('SQLite', 'dumptest_schema_only'), '', '', { RaiseError => 1, AutoCommit => 1 });
    };
    
    SKIP: {
      skip "test requires DBD::SQLite $@", 4 unless $dbh;
      
      my $h = eval {
        my $sth = $dbh->prepare(q{ SELECT * FROM foo });
        $sth->execute;
        $sth->fetchrow_hashref;
      };
      is $@, '', 'did not crash';
      is $h, undef, 'schema only';
      
      $dbh = DBI->connect($server->dsn('SQLite', 'dumptest_schema_and_data'), '', '', { RaiseError => 1, AutoCommit => 1 });
      
      $h = eval {
        my $sth = $dbh->prepare(q{ SELECT * FROM foo });
        $sth->execute;
        $sth->fetchrow_hashref;
      };
      is $@, '', 'did not crash';
      is_deeply $h, { id => 22 }, 'schema only';

    };
    
  };
 
  subtest stop => sub {
    plan tests => 2;
    my $ret = eval { $server->stop };
    is $@, '', 'stop server did not crash';
    ok $ret->is_success, 'stop database';
  };
 
};

subtest 'try to init server with existing data directory' => sub {
  plan tests => 1;
  my $data = dir( tempdir( CLEANUP => 1 ) );
  $data->file('roger.txt')->spew('anything');
  eval { Database::Server::SQLite->new( data => $data )->init };
  like $@, qr{^$data is not empty}, 'died with correct exception';
};

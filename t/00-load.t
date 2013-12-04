#!/usr/bin/env perl

use Test::More tests => 6;

BEGIN {
    use_ok('Carp');
    use_ok('DBI');
    use_ok('DBD::SQLite');
    use_ok('File::Copy');
    use_ok('File::Spec::Functions');
    use_ok('Device::KOBOeReader');
}

diag( "Testing Device::KOBOeReader $Device::KOBOeReader::VERSION, Perl $], $^X" );

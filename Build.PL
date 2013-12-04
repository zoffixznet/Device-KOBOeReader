use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Device::KOBOeReader',
    license             => 'perl',
    dist_author         => q{Zoffix Znet <zoffix@cpan.org>},
    dist_version_from   => 'lib/Device/KOBOeReader.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Carp'                  => 1.11,
        'DBI'                   => 1.609,
        'DBD::SQLite'           => 1.29,
        'File::Copy'            => 2.14,
        'File::Spec::Functions' => 3.33,
    },
    add_to_cleanup      => [ 'Device-KOBOeReader-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

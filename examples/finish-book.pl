#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib ../lib);
use Device::KOBOeReader;

my $kobo = Device::KOBOeReader->new;

$kobo->backup_sql
    or die $kobo->error;

my $now_reading = $kobo->get_now_reading_list;

print "Books in your Now Reading list:\n\n";

my $spacing = int @$now_reading / 10;
printf '%' . $spacing . "s| Title\n",  '#';
for ( 0 .. $#$now_reading ) {
    printf '%' . $spacing . "s| %s\n",
        $_,
        $now_reading->[$_]{title};
}

print "\nPlease enter the number of the book to finish"
    . " (separate multiple numbers with spaces): ";

my @nums = grep {
        $_ =~ /^\d+$/
        and $_ < @$now_reading
        and defined $now_reading->[$_]{title}
    } split ' ', <STDIN>;

@nums or die "...Nothing specified. Exiting\n";

$kobo->finish_book_by_id(
    map $now_reading->[$_]{id}, @nums,
);

print join "\n", "Finished these books:",
    map $now_reading->[$_]{title}, @nums;

print "\nGood bye!\n";

__END__

=head1 USAGE

perl finish-book.pl

=head1 DESCRIPTION

A little script to selectively mark the books on your
I<I'm reading> list as finished.

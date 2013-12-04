package Device::KOBOeReader;

use warnings;
use strict;
our $VERSION = '0.0101';

use Carp;
use DBI;
use DBD::SQLite;
use File::Copy;
use File::Spec::Functions;

sub new {
    my $class = shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = (
        device  => '/media/KOBOeReader',
        @_
    );
    
    $args{ +uc } = delete $args{ $_ } for keys %args;
    
    $args{DEVICE_SQL} = catfile(
        $args{DEVICE},
        '.kobo',
        'KoboReader.sqlite',
    );
    
    croak 'Did not find device SQL database file ('
            . $args{DEVICE_SQL} . ') Check your `device` argument'
        unless -e $args{DEVICE_SQL};

    my $self = bless \%args, $class;

    return $self;
}

sub get_raw_content {
    my $self = shift;
    
    return $self->_dbh->selectall_arrayref(
        'SELECT * FROM `content`',
        { Slice => {} },
    );
}

sub set_read_status_by_id {
    my $self = shift;
    my ( $status, $id ) = @_;
    
    croak "Read type must be 0, 1, or 2"
        unless defined $status
            and $status =~ /^[0-2]$/;

    croak "Missing id"
        unless defined $id
            and length $id;

    $self->_dbh->do(
        'UPDATE `content` SET `ReadStatus` = ? WHERE `ContentID` = ?',
        undef,
        $status,
        $id,
    );
}

sub set_read_status_by_title {
    my $self = shift;
    my ( $status, $title ) = @_;
    
    croak "Read type must be 0, 1, or 2"
        unless defined $status
            and $status =~ /^[0-2]$/;

    croak "Missing title"
        unless defined $title
            and length $title;

    $self->_dbh->do(
        'UPDATE `content` SET `ReadStatus` = ? WHERE `Title` = ?',
        undef,
        $status,
        $title,
    );
}

sub finish_book_by_title {
    my $self = shift;
    my @books = @_;
    
    @books or return;

    $self->_dbh->do(
        'UPDATE `content` SET `ReadStatus` = 2 WHERE `Title` IN('
            . join(', ', ('?') x @books)
            . ')',
        undef,
        @books,
    );
}

sub finish_book_by_id {
    my $self = shift;
    my @books = @_;

    @books or return;

    $self->_dbh->do(
        'UPDATE `content` SET `ReadStatus` = 2 WHERE `ContentID` IN('
            . join(', ', ('?') x @books)
            . ')',
        undef,
        @books,
    );
}

sub get_now_reading_list {
    my $self = shift;
    
    my $items = $self->_dbh->selectall_arrayref(
        'SELECT * FROM `content` WHERE `ReadStatus` = 1',
        { Slice => {} },
    ) || [];
    
    for ( @$items ) {
        my $v = $_;
        $_ = {};
        @$_{qw/
            title
            id
            percent_read
            author
        /}
        = @$v{qw/
            Title
            ContentID
            ___PercentRead
            Attribution
        /};
    }
    
    return $items;
}

sub backup_sql {
    my $self = shift;
    my $dir  = shift;
    
    $dir = '.'
        unless defined $dir
            and length $dir;
    
    my $out_file = catfile( $dir, 'KoboReader.sqlite' );
    
    copy $self->{DEVICE_SQL}, $out_file
        or return $self->_set_error("Backup failed: $!");
        
    return 1;
}

sub _set_error {
    my $self = shift;
    @_ and $self->error( shift );
    
    return;
}

sub _dbh {
    my $self = shift;

    return $self->{DBH}
        if $self->{DBH};

    $self->{DBH} = DBI->connect(
        'dbi:SQLite:dbname=' . $self->{DEVICE_SQL},
        '',
        '',
        { RaiseError => 1, AutoCommit => 1 },
    );

    return $self->{DBH};
}

sub error {
    my $self = shift;
    
    $self->{ERROR} = shift
        if @_;

    return $self->{ERROR};
}


1;

=head1 NAME

Device::KOBOeReader - interface with KOBO eReader

=head1 SYNOPSIS

    use Device::KOBOeReader;
    my $kobo = Device::KOBOeReader->new;

    $kobo->backup_sql
        or die $kobo->error;

    my $now_reading = $kobo->get_now_reading_list;
    
    $kobo->finish_book_by_id( map $_->{id}, @$now_reading );

=head1 WARNING!!!

This module was implemented by poking through the UNDOCUMENTED
innards of a single device. As a result, this code might not work
for you, or even cause your device to blow up! Backup your data
and use at your own risk.

=head1 DESCRIPTION

If you own a KOBO eBook reader, you probably know there's no
easy way to get rid of a book on your I<I'm reading> list of books,
aside from scrolling past last page, or other methods that
at first glance seem complicated.

This module was born out of need to remove some of the (boring)
books on my I<I'm reading> list, and that's pretty much the only useful
thing it does right now. If you have any extra ideas, submit them as
a bug tickets.

=head1 METHODS

=head2 C<new>

    my $kobo = Device::KOBOeReader->new;
    
    my $kobo = Device::KOBOeReader->new( device => '/media/kobo' );

Returns a freshly baked C<Device::KOBOeReader> object. Takes arguments
in a key/value form. Available arguments are as follows:

=head3 C<device>

    my $kobo = Device::KOBOeReader->new( device => '/media/kobo' );

B<Optional>. Takes a path to the mount point of your KOBO reader.
Will croak if the device's SQLite database, located in 
C<$device-mount-point$/.kobo/KoboReader.sqlite>, is not found.
B<Defaults to:> C</media/KOBOeReader>

=head2 C<error>

    $kobo->backup_sql
        or die $kobo->error;

Takes no arguments. Returns a human readable string that is the
explanation of the error that happened after a call to some of the
methods of the object.

=head2 C<backup_sql>
    
    $kobo->backup_sql;
    
    $kobo->backup_sql('/tmp/')
        or die $kobo->error;
    
Copies eReader's SQLite file that contains device's guts. Takes one
optional argument that specifies the directory where to backup the
file. If not specified, defaults to current directory. If an error
occurs, returns C<undef> or an empty list, depending on the context,
and the human readable description of the error will be available
through C<error()> method.

=head2 C<get_raw_content>

    my $raw_content_array_ref = $kobo->get_raw_content;

Takes no arguments. Returns an arrayref that contains all records in
device's C<content> table. Each element of the arrayref is a hashref
that represents one row in the table and whose keys are column names.

=head2 C<set_read_status_by_id>

    $kobo->set_read_status_by_id(
        2,
        'file:///mnt/onboard/Books-to-Read/Kobo_eReader_User_Guide.epub'
    );

Sets the C<ReadStatus> column in device's C<content> table to one
of three possible values. The row will be identified by C<ContentID>
column.

The method takes two mandatory arguments. First is the 
C<ReadStatus> value; where C<0> is unfinished book that is B<not> on
I<I'm reading> list, C<1> is unfinished book that is on the
C<I'm reading> list, and C<2> is finished book.

The second argument is the C<ContentID> of the items whose C<ReadStatus>
you want to change.

=head2 C<set_read_status_by_title>

    $kobo->set_read_status_by_title(
        2,
        'Crime And Punishment'
    );

Same as C<set_read_status_by_id()> above, except instead of
C<ContentID>, it uses the value in C<Title> column that is specified
by the second argument.

=head2 C<finish_book_by_id>

    $kobo->finish_book_by_id(
        'cab2c7bb-9c32-4758-b898-d16d05e0ec78',
        'file:///mnt/onboard/Digital Editions/Breaking_the_Time_Barrier.epub',
        'file:///mnt/onboard/Digital Editions/Multiple_Intelligences.epub',
        
    );
    
Sets C<ReadStatus> column to value C<2> (finished book) for one
or more books identified via their C<ContentID> column. Takes one
or more arguments that represent the C<ContentID> values of the
books.

=head2 C<finish_book_by_title>

    $kobo->finish_book_by_title(
        'Crime And Punishment',
        'Breaking the Time Barrier',
        'Multiple Intelligences',
    );

Same as C<finish_book_by_id()> above, except will find right items
using values in C<Title> column. These titles is what the method
expects as arguments.

=head2 C<get_now_reading_list>

    my $now_reading_books = $kobo->get_now_reading_list;

    # Output:
    $VAR1 = [
      {
        'percent_read' => 22,
        'author' => 'Fyodor Dostoevsky',
        'id' => 'cab2c7bb-9c32-4758-b898-d16d05e0ec78',
        'title' => 'Crime And Punishment'
      },
      ....
    ];

Takes no arguments. Returns a possibly empty arrayref, each item
of which is a hashref that represents one item on your
I<I'm reading> list. Each hashref will contain the following keys/values:

=head3 C<id>
    
    {
        'id' => 'cab2c7bb-9c32-4758-b898-d16d05e0ec78',
    ...

This is the value of C<ContentID> column in device's table. This is
what C<*_by_id> methods want.

=head3 C<title>
    
    {
        'title' => 'Crime And Punishment'
    ...

This is the value of C<Title> column in device's table. Represents
the title of the item; this is what C<*_by_title> methods want.

=head3 C<author>

    {
        'author' => 'Fyodor Dostoevsky',
    ...

This will be the value of C<Attribution> column in device's table,
which, I understand, contains the author of the book/item.

=head3 C<percent_read>

    {
        'percent_read' => 22,
    ...

Returns a number or an C<undef> that represents how much of the item
you have read (the C<___PercentRead> column in device's table).

=head1 EXAMPLES

The C<examples/> directory of this distibution contains a short example
script that you can use to selectively mark the books on your
I<I'm reading> list as finished.

=head1 REQUIRED MODULES

As a balanced diet, this module requires the following
modules/versions:

    Carp                  => 1.11,
    DBI                   => 1.609,
    DBD::SQLite           => 1.29,
    File::Copy            => 2.14,
    File::Spec::Functions => 3.33,

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com/>, L<http://haslayout.net/>,
L<http://mind-power-book.com/>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-device-koboereader at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-KOBOeReader>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Device::KOBOeReader

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-KOBOeReader>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-KOBOeReader>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-KOBOeReader>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-KOBOeReader/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Zoffix Znet.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

package Roku::DVP::Remote;

use 5.010001;
use strict;
use warnings;

our $VERSION = '0.01';

use strict;
use warnings;
{
    use URI;
    use Carp;
    use Readonly;
    use IO::Socket::INET;
    use Net::Ifconfig::Wrapper;
    use Net::Ping qw( pingecho );
    use English qw( -no_match_vars $INPUT_RECORD_SEPARATOR $OS_ERROR );
}

my ( %IS_KEY, $DEFAULT_PORT, $ROKU_TEST_TIMEOUT );
{
    Readonly %IS_KEY => (
        Back          => 1,
        Backspace     => 1,
        Down          => 1,
        Enter         => 1,
        Fwd           => 1,
        Home          => 1,
        Info          => 1,
        InstantReplay => 1,
        Left          => 1,
        Play          => 1,
        Rev           => 1,
        Right         => 1,
        Search        => 1,
        Select        => 1,
        Up            => 1,
    );
    Readonly $DEFAULT_PORT      => 8060;
    Readonly $ROKU_TEST_TIMEOUT => 0.0095;
}

sub sniff {
    my ($port) = @_;

    $port ||= $DEFAULT_PORT;

    my @rokus;

    my @quad;

    my $info_rh = Net::Ifconfig::Wrapper::Ifconfig('list');

    IFACE:
    for my $iface ( keys %{$info_rh} ) {

        next IFACE
            if $iface eq 'lo';

        next IFACE
            if not $info_rh->{$iface}->{status};

        next IFACE
            if not $info_rh->{$iface}->{inet};

        my ($ip) = keys %{ $info_rh->{$iface}->{inet} };

        next IFACE
            if not $ip;

        @quad = split /\D/, $ip;

        last IFACE
            if @quad >= 4;
    }

    my $last_octet = pop @quad;

    OCTET:
    for my $octet ( 1 .. 999 ) {

        next OCTET
            if $octet == $last_octet;

        my $ip = join '.', ( @quad, $octet );

        next OCTET
            if not _is_a_roku( $ip, $port );

        push @rokus, sprintf '%s:%d', $ip, $port;
    }

    return \@rokus;
}

sub new {
    my ( $class, $address ) = @_;

    croak __PACKAGE__ . "::new -- address not provided"
        if not $address;

    if ( $address !~ m{\A http }xmsi ) {

        $address = "http://$address";
    }

    my $uri = URI->new( $address );

    croak __PACKAGE__ . "::new -- couldn't parse address '$address'"
        if not $uri;

    croak __PACKAGE__ . "::new -- $address unreachable"
        if not pingecho( $uri->host() );

    if (   $uri->port() == 80
        && $address !~ m{ :80 (?: \D | \z ) }xms )
    {
        $uri->port( $DEFAULT_PORT );
    }

    $address = $uri->canonical();

    my %self = (
        port     => $uri->port(),
        host     => $uri->host(),
        address  => $address,
    );
    return bless \%self, $class;
}

sub get_valid_keys {

    return sort keys %IS_KEY;
}

sub query_apps {
    my ( $self ) = @_;

    my ( $success, $content ) = $self->_post( 'query/apps' );

    return $success;
}

sub keydown {
    my ( $self, $key ) = @_;

    croak "$key is not a recognized key"
        if not _validate_key( \$key );

    return $self->_post( "keydown/$key" );
}

sub keyup {
    my ( $self, $key ) = @_;

    croak "$key is not a recognized key"
        if not _validate_key( \$key );

    return $self->_post( "keyup/$key" );
}

sub keypress {
    my ( $self, $key ) = @_;

    croak "$key is not a recognized key"
        if not _validate_key( \$key );

    ## return $self->_post( "keypress/$key" );

    $self->_post( "keydown/$key" );
    return $self->_post( "keyup/$key" );
}

sub launch {
    my ( $self ) = @_;

    return $self->_post( 'launch' );
}

sub query_icons {
    my ( $self ) = @_;

    my ( $success, $content ) = $self->_post( 'query/icons' );

    return $success;
}

sub touchdown {
    my ( $self, $x, $y ) = @_;

    return $self->_post( "touchdown/$x.$y" );
}

sub touchup {
    my ( $self, $x, $y ) = @_;

    return $self->_post( "touchup/$x.$y" );
}

sub touchdrag {
    my ( $self, $x, $y ) = @_;

    return $self->_post( "touchdrag/$x.$y" );
}

#** Internal Helpers **#

sub _post {
    my ( $self, $path ) = @_;

    my $address = sprintf '%s:%d', $self->{host}, $self->{port};

    my $socket = IO::Socket::INET->new($address);

    croak "unable to connect to '$address'"
        if not $socket;

    my $command = "POST /$path HTTP/1.1\r\n\r\n";

    print {$socket} $command
        or warn "print: $OS_ERROR";

    shutdown $socket, 1
        or warn "shutdown: $OS_ERROR";

    my $result_txt;
    {
        local $INPUT_RECORD_SEPARATOR;
        $result_txt = <$socket>;
    }

    close $socket
        or warn "close: $OS_ERROR";

    return $result_txt || "";
}

sub _validate_key {
    my ( $key_rs ) = @_;

    ${ $key_rs } ||= "";
    ${ $key_rs } = ucfirst ${ $key_rs };

    return 1
        if exists $IS_KEY{ ${ $key_rs } };

    return;
}

sub _is_a_roku {
    my ( $ip, $port ) = @_;

    my $address = sprintf '%s:%d', $ip, $port;

    my $socket = IO::Socket::INET->new(
        PeerAddr => $address,
        Timeout  => $ROKU_TEST_TIMEOUT,
    );

    return
        if not $socket;

    my $command = "NOOP\r\n\r\n";

    print {$socket} $command
        or warn "print: $OS_ERROR";

    shutdown $socket, 1
        or warn "shutdown: $OS_ERROR";

    my $result_txt;
    {
        local $INPUT_RECORD_SEPARATOR;
        $result_txt = <$socket>;
    }

    close $socket
        or warn "close: $OS_ERROR";

    $result_txt ||= "";

    # HTTP/1.1 400 Bad Request
    # Content-Length: 0
    # Server: Roku UPnP/1.0 MiniUPnPd/1.4
    return 1
        if $result_txt =~ m{ \s Roku \s }xmsi;

    return;
}

1;

__END__

=head1 NAME

Roku::DVP::Remote - Module for interfacing with your Roku DVP.

=head1 SYNOPSIS

  use Roku::DVP::Remote;

  my $roku = Roku::DVP::Remote->new( '192.168.1.101' );

  my $response = $Roku->keypress('Home');

  die "failed to go Home"
      if $response !~ m{ OK }xms;

=head1 DESCRIPTION

Use this module to write programs which interact with your Roku DVP.

Check the example directory for the remote.pl which uses XUL::Gui to make
a neat Roku remote you can run anywhere you like.

=head1 AUTHOR

Dylan Doxey, E<lt>dylan.doxey@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Dylan Doxey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

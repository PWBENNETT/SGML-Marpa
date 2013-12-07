package SGML::Marpa::PI::xml;

use base qw( SGML::Marpa );

sub make {
    my $self = shift;
    $self->{ fragments }->{ Prolog } =~ s/Prolog ::= OPList DTD DTDOP LTDOP/Prolog ::= OPList DTDOP LTDOP/smg;
    $self->{ fragments }->{ L0 } =~ s{^netc ~ '/'$}{netc ~ '>'}smg;
    return $self->SUPER::make;
}

1;

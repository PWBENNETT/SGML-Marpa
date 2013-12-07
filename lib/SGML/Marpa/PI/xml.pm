package SGML::Marpa::PI::xml;

use base qw( SGML::Marpa );

sub make {
    my $self = shift;
    $self->{ fragments }->{ Prolog } = xml_prolog();
    my $g = $self->{ fragments }->{ DefaultG0 };
    $g =~ s{^netc ~ '/'$}{netc ~ '>'}smg;
    $self->{ fragments }->{ DefaultG0 } = $g;
    return $self->SUPER::make;
}

sub xml_prolog {
    # remove the "pure SGML" requirement for at least one DTD
    # NB: DTDs (if any) still have to come before LTDs (if any)
    return << 'MARPA';
Prolog ::= OPList DTDOP LTDOP
DTDOP ::= DTD DTDOP
        | OtherProlog DTDOP
        | Nil
LTDOP ::= LTD LTDOP
        | OtherProlog LTDOP
        | Nil
OPList ::= OtherProlog+ separator => s proper => 1
OtherProlog ::= CommentDeclaration
              | ProcessingInstruction
              | s
              | Nil
MARPA
}

1;

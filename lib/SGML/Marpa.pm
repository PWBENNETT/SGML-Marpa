package SGML::Marpa;

use 5.018;
use utf8;

use IO::All;
use Marpa::R2;

push @INC, sub {
    my ($self, $filename) = @_;

    # TODO find the right pathsep instead of guessing
    my $wanted = join('::', split m{(?:(?:\\)+|/)}, $filename);
    $wanted =~ s/\.pm$//;

    my (undef, $call_file) = caller;
    my $ext = io($call_file)->ext;
    my $directory = io($call_file)->absolute->canonpath();
    $directory =~ s/\.$ext$//;
    my $grammar_name = io->catfile($directory, $filename)->absolute->canonpath();
    $grammar_name =~ s/\.pm$/.slif/;

    if (!-f $grammar_name) {
        $directory = $INC{io->catfile(qw( SGML Marpa.pm ))->relative->canonpath()};
        $directory =~ s/\.pm$//;
        $grammar_name = io->catfile($directory, $filename)->absolute->canonpath();
    }

    return unless -f $grammar_name;

    my @prolog = (
        "package $wanted;\n",
        "use 5.018;\n",
        "use utf8;\n",
        "sub get {\n",
        "return <<'MARPA';\n",
    );

    my @lines = io($grammar_name)->slurp;
    $lines[ -1 ] .= "\n" unless substr($lines[ -1 ], -1) eq "\n";

    my @epilog = (
        "MARPA\n",
        "}\n",
        "1;\n",
    );

    my @rv = (@prolog, @lines, @epilog);

    return sub {
        if (@rv) {
            $_ = shift @rv;
            return 1;
        }
        return 0;
    };
};

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $class = shift;
    my %args = eval { keys %{$_[0]} } ? %{$_[0]} : @_;
    my $frags = delete($args{ fragments }) || { };
    my $system = delete($args{ system });
    my $prefix = delete($args{ prefix }) || [ ];
    %args = (
        fragments => {
            Abstract => 'Abstract',
            Axiomatic => 'Axiomatic',
            DTD => 'DTD',
            L0 => 'L0',
            LTD => 'LTD',
            Prolog => 'Prolog',
            SGMLDeclaration => 'SGMLDeclaration',
            SystemDeclaration => 'SystemDeclaration',
            %$frags,
        },
        prefix => [ ($system ? $system : ()), @$prefix ],
        %args,
        semantics_package => 'SGML::Marpa::Semantics',
    );
    my $self = bless \%args => $class;
    return $self->make();
}

sub parse {
    my $self = shift;
    my ($string) = @_;
    my $full_length = length $string;
    my $re = $self->{ recce };
    for (
        my $pos = $re->read(\$string);
        $pos < $full_length;
        $pos = $re->resume()
    ) {
        my ($start, $length) = $re->pause_span();
        for my $ev (@{$re->events}) {
            my ($name) = @$ev;
            if ($name eq 'PI') {
                # Argh, now what???
                # I need to make a new G and a new R and tell the new R to
                # resume() at $start + $length, I think, but it's all weird
            }
        }
    }
}

sub make {
    my $self = shift;
    my $full_prefix = join "\n", map {
        eval { $self->_try_to_get_plugin($_)->get() } // $_
    } @{$self->{ prefix }}
    ;
    $self->{ slif } = join "\n", map {
        (my $plugin = $self->_try_to_get_plugin($_))
        ? do {
            $self->{ fragments }->{ $_ } = $plugin->get();
        }
        : $self->{ fragments }->{ $_ }
    } keys %{$self->{ fragments }}
    ;
    my $whole_shebang = $full_prefix . "\n" . $self->{ slif };
    $self->{ grammar } = Marpa::R2::Scanless::G->new(source => \$whole_shebang);
    $self->{ old_recce } = delete($self->{ recce }) if $self->{ recce };
    $self->{ recce } = Marpa::R2::Scanless::R->new(
        grammar => $self->{ grammar },
        semantics_package => $self->{ semantics_package },
    );
    return $self;
}

sub prepend_prefix {
    my $self = shift;
    unshift @{$self->{ prefix }}, @_;
    return $self;
}

sub append_prefix {
    my $self = shift;
    push @{$self->{ prefix }}, @_;
    return $self;
}

sub _try_to_get_plugin {
    my $self = shift;
    my ($plugname) = @_;
    my @pieces = split /::/, ref $self;
    my @prefixes = (
        join('::', @pieces) . '::',
        join('::', @pieces[ 0 .. $#pieces - 1]) . '::'
    )
    for my $bit (grep { $_ ne $pieces[ -1 ] } qw( Fragment PI System )) {
        push @prefixes, join('::', @pieces[ 0 .. $#pieces - 1]) . '::'. $bit . '::',
    }
    push @prefixes, '';
    my $plugin;
    for my $pfx (@prefixes) {
        my $package = $pfx . $plugname;
        eval "require $package" or next;
        $plugin = $package;
        last;
    }
    return unless $plugin;
    return $plugin;
}

sub IsDataChar {
    return <<'DC';
+utf8::IsAscii
-0A
-0E
-20
-26
-3C
DC
}

1;

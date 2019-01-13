package Test::LazyMock::Overloaded;
use strict;
use warnings;
use overload (
    '${}' => sub { _overload_nomethod(@_, '${}') },
    '@{}' => sub { _overload_nomethod(@_, '@{}') },
    # '%{}' => sub { _overload_nomethod(@_, '%{}') },
    '&{}' => sub { _overload_nomethod(@_, '&{}') },
    '*{}' => sub { _overload_nomethod(@_, '*{}') },
    'nomethod' => \&_overload_nomethod,
);
use parent qw(Test::LazyMock);

my %default_overload_handlers = (
    '${}' => sub { \ my $x },
    '@{}' => sub { [] },
    # '%{}' => sub { +{} },
    '&{}' => sub { sub {} },
    '*{}' => sub { \*DUMMY },
);

sub _overload_nomethod {
    my ($self, $other, $is_swapped, $operator, $is_numeric) = @_;

    $self->_call_method(
        $operator => [$other, $is_swapped],
        $default_overload_handlers{$operator},
    );
}

1;
__END__

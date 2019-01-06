package Test::LazyMock;
use 5.008001;
use strict;
use warnings;
use Scalar::Util qw(weaken);

our $VERSION = "0.01";

sub new {
    my $class = shift;
    my %params = @_;

    my $self = bless {
        _lazymock_methods => {},  # method name => code-ref
        _lazymock_name => $params{name},
        _lazymock_parent => $params{parent},
        _lazymock_children => {},  # name => instance
        _lazymock_calls => [],
    } => $class;

    # parse all method definitions
    while (my ($k, $v) = each %{$params{methods} // {}}) {
        $self->lazymock_add_method($k => $v);
    }

    $self;
}

sub lazymock_add_method {
    my ($self, $name, $code_or_value) = @_;

    my ($method, $child_method) = split /->/, $name, 2;

    # check duplicates with pre-defined methods
    die "`$method` has already been defined as a method"
        if exists $self->{_lazymock_methods}{$method};

    # handle nested method definitions
    if (defined $child_method) {
        my $child = $self->lazymock_child($method);
        $child->lazymock_add_method($child_method, $code_or_value);
        return;
    }

    # check duplicates with fields
    die "`$method` has already been defined as a field"
        if exists $self->{_lazymock_children}{$method};

    my $code;
    if (ref $code_or_value // '' eq 'CODE') {
        $code = $code_or_value;
    } else {
        $code = sub { $code_or_value };
    }

    $self->{_lazymock_methods}{$name} = $code;
}

sub lazymock_calls { @{$_[0]->{_lazymock_calls}} }

sub lazymock_child {
    my ($self, $name) = @_;

    return if exists $self->{_lazymock_methods}{$name};

    $self->{_lazymock_children}{$name} //= do {
        # create new child
        weaken(my $weaken_self = $self);
        my $child_mock = ref($self)->new(
            name => $name,
            parent => $weaken_self,
        );

        $self->{_lazymock_children}{$name} = $child_mock;

        $child_mock;
    };
}

sub lazymock_reset {
    my $self = shift;
    $self->{_lazymock_calls} = [];
    $_->lazymock_reset for values %{$self->{_lazymock_children}};
}

sub DESTROY {}

sub AUTOLOAD {
    my ($self, @params) = @_;
    (my $meth = our $AUTOLOAD) =~ s/.*:://;

    # follow up the chain of mocks and record calls
    my %seen;
    my $cur_call = [$meth, \@params];
    my $cur_mock = $self;
    while ($cur_mock && ! $seen{int($cur_mock)}++) {
        push @{$cur_mock->{_lazymock_calls}}, $cur_call;

        $cur_call = [
            join('->', $cur_mock->{_lazymock_name} // '', $cur_call->[0]),
            $cur_call->[1],
        ];
        $cur_mock = $cur_mock->{_lazymock_parent};
    }

    # return value
    if (my $code = $self->{_lazymock_methods}{$meth}) {
        $code->(@params);
    } else {
        $self->lazymock_child($meth);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Test::LazyMock - It's new $module

=head1 SYNOPSIS

    use Test::LazyMock;

=head1 DESCRIPTION

Test::LazyMock is ...

=head1 LICENSE

Copyright (C) Masahiro Honma.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Masahiro Honma E<lt>hiratara@cpan.orgE<gt>

=cut


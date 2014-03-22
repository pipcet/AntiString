use strict;
use warnings;
package String::AntiString;

# ABSTRACT: extend strings to include formal inverses

use overload
    '+' => \&concat,
    'neg' => \&negate,
    '-' => \&minus,
    '""' => \&safe_stringify,
    '.' => \&concat;

sub upgrade {
    my ($self) = @_;

    return $self if ref($self);

    return String::AntiString->new($self);
}

sub copy {
    my ($self) = @_;

    my $result = String::AntiString->new("");
    $result->append($self);

    return $result;
}

sub negate {
    my ($self) = @_;
    my $result = $self->copy;
    unshift @{$result->{stack}}, "";
    push @{$result->{stack}}, "";

    return $result;
}

sub concat {
    my ($self, $other, $swap) = @_;

    return concat($other, $self) if $swap;

    my $result = String::AntiString->new("");
    $result->append(upgrade($self));
    $result->append(upgrade($other));

    return $result;
}

sub minus {
    my ($self, $other, $swap) = @_;

    if ($swap) {
	return concat(upgrade($other), negate(upgrade($self)));
    } else {
	return concat(upgrade($self), negate(upgrade($other)));
    }
}

sub append {
    my ($self, $arg) = @_;

    push @{$self->{stack}}, @{$arg->{stack}};

    $self->normalize;

    return $self;
}

sub normalize {
    my ($self) = @_;
    my $oldstack = $self->{stack};
    my $newstack = \@$oldstack;

    my $didsomething = 1;

    while ($didsomething) {
	$didsomething = 0;

	for my $i (0..$#{$newstack}-1) {
	    next if $newstack->[$i] eq "";

	    while ($newstack->[$i] ne "" and
		   substr($newstack->[$i], -1) eq substr($newstack->[$i+1], -1)) {
		$newstack->[$i] =~ s/.$//msg;
		$newstack->[$i+1] =~ s/.$//msg;
		$didsomething = 1;
	    }
	}

	for (my $i=0; $i<$#{$newstack}; $i++) {
	    if ($newstack->[$i] eq "" and
		$newstack->[$i+1] eq "") {
		splice(@$newstack, $i, 2);
		$i--;
		$didsomething = 1;
	    }
	}

	$self->{stack} = $newstack;
    }
}

sub safe_stringify {
    my ($self) = @_;
    my $ret = "";

    $self->normalize;
    my $stack = $self->{stack};

    for (my $i=0; $i<=$#{$stack}; $i++) {
	next if $stack->[$i] eq "";

	die if ($i&1);

	$ret .= $stack->[$i];
    }

    return $ret;
}

sub import {
    overload::constant q => sub {
	my ($initial, $interpreted, $howused) = @_;
	upgrade($interpreted);
    };
}

sub new {
    my ($class, $str) = @_;
    my $self = bless {}, $class;

    $self->{stack} = [$str, ""];

    return $self;
}

1;

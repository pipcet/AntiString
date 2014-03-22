use strict;
use warnings;
package String::AntiString;

# ABSTRACT: extend strings to include formal inverses

use overload
    '+' => \&concat,
    'neg' => \&negate,
    '-' => \&minus,
    '""' => \&safe_stringify,
    '.' => \&concat,
    'eq' => \&eq;

sub eq {
    my ($self, $other, $swap) = @_;

    if ($swap) {
	$self = upgrade($self);
    } else {
	$other = upgrade($other);
    }

    my $stack_a = $self->{stack};
    my $stack_b = $other->{stack};

    return 0 if $#{$stack_a} != $#{$stack_b};

    for my $i (0 .. $#{$stack_a}) {
	return 0 if $stack_a->[$i] ne $stack_b->[$i];
    }

    return 1;
}

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


	    if (($i&1) == 0) {
		while ($newstack->[$i] ne "" and
		       substr($newstack->[$i], -1) eq substr($newstack->[$i+1], -1)) {
		    $newstack->[$i] =~ s/.$//msg;
		    $newstack->[$i+1] =~ s/.$//msg;
		    $didsomething = 1;
		}
	    } else {
		while ($newstack->[$i] ne "" and
		       substr($newstack->[$i], 0, 1) eq substr($newstack->[$i+1], 0, 1)) {
		    $newstack->[$i] =~ s/^.//msg;
		    $newstack->[$i+1] =~ s/^.//msg;
		    $didsomething = 1;
		}
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

sub representation {
    my ($self) = @_;

    my $res = "";

    my $stack;
    for my $i (0..$#{$stack}) {
	if ($i&1) {
	    $res .= " - ";
	} elsif ($i > 0) {
	    $res .= " + ";
	}

	$res .= "\"" . $stack->[$i] . "\"";
    }

    return $res;
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

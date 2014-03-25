use strict;
use warnings;
package String::AntiString;

use String::Escape qw(quote);

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

    $self->slow_normalize;

    return $self;
}

sub letters {
    my ($self) = @_;
    my $stack = $self->{stack};
    my @res;
    for(my $i=0; $i<=$#{$stack}; $i++) {
	my $str = $stack->[$i];
	if ($i&1) {
	    for (my $j=length($str)-1; $j>=0;$j--) {
		push @res, [substr($str, $j, 1), -1];
	    }
	} else {
	    for (my $j=0; $j<length($str);$j++) {
		push @res, [substr($str, $j, 1), 1];
	    }
	}
    }

    return @res;
}

sub slow_normalize {
    my ($self) = @_;
    my @letters = $self->letters;

    my $didsomething = 1;
  loop:
    while($didsomething) {
	$didsomething = 0;
	for my $i (0..$#letters-1) {
	    if ($letters[$i][0] eq $letters[$i+1][0] and
		$letters[$i][1] != $letters[$i+1][1]) {
		splice(@letters, $i, 2);
		$didsomething = 1;
		next loop;
	    }
	}
    }

    my @stack;
    my $i = 0;
    while($i <= $#letters) {
	my $j = $i;

	while($j <= $#letters and $letters[$j][1] == 1) {
	    $j++;
	}
	push @stack, join("", map { $letters[$_][0] } ($i..$j-1));
	$i = $j;

	while($j <= $#letters and $letters[$j][1] == -1) {
	    $j++;
	}
	push @stack, join("", reverse map { $letters[$_][0] } ($i..$j-1));
	$i = $j;
    }

    $self->{stack} = \@stack;

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

	for (my $i=0; $i<=$#{$newstack}; $i++) {
	    if ($newstack->[$i] eq "") {
		my $prefi = ($i>0) ? $i-1 : 0;
		my $posti = ($i<$#{$newstack}) ? $i+1 : $i;

		my $pref = ($i>0) ? $newstack->[$i-1] : "";
		my $post = ($i<$#{$newstack}) ? $newstack->[$i+1] : "";

		splice(@$newstack, $prefi, $posti-$prefi, $pref.$post);
		push @$newstack, "" if (($prefi-$posti)&1);
		$i = $prefi+1;
		$didsomething = 1 if $posti>$prefi+1;
	    }
	}

	$self->{stack} = $newstack;
    }

    return $self;
}

sub representation {
    my ($self) = @_;

    my $res = "";

    my $stack = $self->{stack};
    for my $i (0..$#{$stack}) {
	if ($i&1) {
	    $res .= " - ";
	} elsif ($i > 0) {
	    $res .= " + ";
	}

	$res .= quote($stack->[$i]);
    }

    return $res;
}

sub signed_length {
    my ($self) = @_;
    my $res = 0;

    my $stack = $self->{stack};
    for my $i (0..$#{$stack}) {
	if ($i&1) {
	    $res -= length($stack->[$i]);
	} elsif ($i > 0) {
	    $res += length($stack->[$i]);
	}

	$res .= quote($stack->[$i]);
    }

    return $res;
}

sub safe_stringify {
    my ($self) = @_;
    my $ret = "";

    $self->slow_normalize;
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

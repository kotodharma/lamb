use strict;
no strict 'refs';

our %VAR;

my @Sentences = (
    ['John', 'died'],
    ['John', ['loves', 'Mary']],
    [['the', 'man'], ['loves', 'Mary']],
    ['Austin', ['is', [['a', 'city'], ['in', 'Texas']]]],
    [['the', ['stairway', ['in', 'CAIL']]], ['is', 'dirty']],
    [['the', ['stairway', ['which', ['*', ['is', ['in', 'CAIL']]]]]], ['is', 'dirty']],
    [['A', ['dirty', ['man', ['who', ['Mary', ['loves', '*']]]]]], 'died'],
);

my %Lex = (
      died => '&x=e.{x} died=t',
     loves => '&x=e.&y=e.{y} loves {x}=t',
        is => '&f=<e,t>.{f}=<e,t>',
         a => '&f=<e,t>.{f}=<e,t>',    ## note two versions of indefinite article
         A => '&g=<e,t>.an existing z such that {g}(z)=e',
        in => '&x=e.&y=e.{y} is in {x}=t',
      city => '&x=e.{x} is a city=t',
       man => '&x=e.{x} is a man=t',
  stairway => '&x=e.{x} is a stairway=t',
     dirty => '&x=e.{x} is dirty=t',
       the => '&f=<e,t>.the unique y such that {f}(y)=e',
     which => 'relpro=r',
       who => 'relpro=r',
       '*' => '{trace}=e'
);

foreach my $s (@Sentences) {
    my $r = resolve($s);
    print ${$r}, ": ", ref($r), "\n";
}

## END OF MAIN

sub resolve {
    my($constit) = @_;

    my $child0 = denote( lex_value($constit->[0]) );
    my $child1 = denote( lex_value($constit->[1]) );
    my $type0 = typeOf($child0);
    my $type1 = typeOf($child1);

    if ($type0 eq 'ARRAY') {        ## non-terminal node
        $child0 = resolve($child0);
        $type0 = typeOf($child0);
    }
    if ($type1 eq 'ARRAY') {        ## non-terminal node
        $child1 = resolve($child1);
        $type1 = typeOf($child1);
    }
    my($dom0) = getDomainRange($type0);
    my($dom1) = getDomainRange($type1);

    if ($type0 eq 'r') {
        pa($child1);
    }
    elsif ($type0 eq '<e,t>' && $type1 eq '<e,t>') {
        pm($child0, $child1);
    }
    elsif ($dom0 eq $type1) {
        fa($child0, $child1);
    }
    elsif ($dom1 eq $type0) {
        fa($child1, $child0);
    }
    else {
        die "Unknown resolution type: |$type0|$type1|\n";
    }
}

sub denote {
    my $le = shift;
    my %VAR = @_;
    return $le if ref $le;

    my $type = typeOf($le);
    my $r;

    if ($le =~ s/^&//) {
        my($var, $input, $expr) = split /[.=]/, $le, 3;
        my $id = int rand 10000;     ## get a random 4-digit number
        $expr =~ s/\{$var\}/{$id}/g; ## replace vars with numeric ids
                                     ##     for uniqueness
        $r = sub {
            $VAR{$id} = shift;
            denote($expr, %VAR);
        };
    }
    else {
        my($body, $output) = split /=/, $le;
        $r = eval_body($body, %VAR);
    }
    bless $r, $type;
}

sub eval_body {
    my($body, %VAR) = @_;
    my @chunks = split /( \{\d+\} | [()] )/x, $body;
    my @result;

    while (@chunks) {
        my $chunk = shift @chunks;

        if ($chunk eq '' || $chunk eq '(') {
            next;   ## ignore semantically empty bits
        }
        elsif ($chunk =~ /\{(\d+)\}/) {
            push @result, $VAR{$1};
        }
        elsif ($chunk eq ')') {
            my $arg = pop @result;
            my $func = pop @result;
            push @result, $func->($arg);
        }
        else {
            push @result, $chunk;
        }
    }

    my $r = $result[0];
    if (@result > 1 || not ref $r) {
        my $cat = join '', map { ${$_} || $_ } @result;
        $r = \$cat;
    }
    return $r;
}

sub pm {
    my($p0, $p1) = @_;

    my $f = sub {
        my $x = shift;
        my $a = $p0->($x);
        my $b = $p1->($x);
        my $conj = "${$a} and ${$b}";
        bless \$conj, 't';
    };
    bless $f, '<e,t>';
}

sub pa {
    my($kid) = @_;
    my $type = typeOf($kid);

    my $r = sub {
        my $ASGN = shift;
        ${$kid} =~ s/\{trace\}/$ASGN/;
        $kid;
    };
    bless $r, "<e,$type>";
}

sub fa {
    my($func, $arg) = @_;
    $func->($arg);
}

sub lex_value {
    my($node) = @_;

    if (exists $Lex{$node}) {
        $Lex{$node};
    }
    elsif (ref $node) {
        $node;
    }
    else {
        "^$node=e";   ## entity not explicitly in lexicon
    }
}

sub typeOf {
    my($expr) = @_;

    if (ref $expr) {
        ref $expr;
    }
    elsif ($expr =~ s/^&//) {
        my($var, $input, $subexpr) = split /[.=]/, $expr, 3;
        sprintf "<%s,%s>", $input, typeOf($subexpr);
    }
    else {
        my($body, $output) = split /=/, $expr;
        $output;
    }
}

sub getDomainRange {
    my($type) = @_;
    my @chars = split /\s*/, $type;
    shift @chars;
    pop @chars;

    my $domain;
    if ($chars[0] eq '<') {
        my $i = 0;
        while (my $c = shift @chars) {
            $domain .= $c;

            if ($c eq '<') {
                $i++;
            }
            elsif ($c eq '>') {
                last if --$i == 0;
            }
        }
    }
    else {
        $domain = shift @chars;
    }
    shift @chars;  ## lose the comma
    return ($domain, join('', @chars));
}

__END__

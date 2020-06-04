grammar Parser {
  rule TOP       { <ws> <decl> * }
  rule decl      { <const> | <var> |
                   <essential> | <floating> | <distinct> |
                   <axiom> | <theorem> |
                   <push_fr> | <pop_fr> }
  token comment  { '$(' .*? '$)' }
  token ws       { \s* [<comment>\s*]* }

  rule const     { '$c' <symbol> + '$.' }
  rule var       { '$v' <symbol> + '$.' }

  rule essential { <label> '$e' <symbol> + '$.' }
  rule floating  { <label> '$f' <type=symbol> <var=symbol> '$.' }
  rule distinct  { '$d' <symbol> + '$.' }

  # Kludge: No whitespace before the closing brace below.
  # This is so that $!latest_comment is the one before the assertion, not the
  # one after.
  rule axiom     { <label> '$a' <symbol> + '$.'}
  rule theorem   { <label> '$p' <symbol> + '$=' <proof> '$.'}

  # TODO uncompressed proofs
  rule proof     { '(' <label> * ')' $<compressed>=(<[A..Z]> *) }

  token push_fr  { '${' }
  token pop_fr   { '$}' }

  token label    { <[\w._-]>+ }
  token symbol   { <[\S] - [$]>+ }
}

class Essential {
  has $.statement;

  method essential { True }
}

class Floating {
  has $.type;
  has $.var;

  method essential { False }
  method statement { [$.type, $.var] }
}

class Frame {
  has $.parent = Nil;
  has @.const;
  has @.var;
  has @.hypotheses;

  method traverse () {
    gather loop (my $l = self; $l; $l.=parent) {
      take $l;
    }
  }
}

# TODO:
# Unify the names "assumptions" and "hypotheses" somehow, and make it a %.
# Make proof_steps a class with statement, previous steps and inference statement
class Assertion {
  has $.comment;
  has @.assumptions;
  has @.statement;
  has @.proof_steps;

  submethod BUILD(Str :$comment, Frame :$frame,
                  :@!statement, :$proof, :%previous_statements) {
    $!comment = $comment;

    my @frames = $frame.traverse.reverse;
    my @hypotheses = @frames».hypotheses».Slip.flat;

    my @symbols = @!statement;
    @symbols.append(.value.statement)
      for @hypotheses.grep: { $_.value.essential };
    @hypotheses .= grep: {
      .value.essential or .value.var ∈ @symbols;
    }

    @!assumptions = @hypotheses;

    if $proof {
      my @proof_statements = $proof<label>
        ?? (%previous_statements{$proof<label>}:p)
        !! [];
      @proof_statements.prepend(@!assumptions);
      
      my @proof_letters = $proof<compressed>.comb(rx/<[A..Z]>/);
      my @stack = [];

      for @proof_letters {
        if $_ eq 'Z' {
          @proof_statements.push(@!proof_steps.elems => Essential.new(statement => @!proof_steps[*-1][0]));
        } else {
          my $proof_int = ord($_) - ord('A');
          my ($label, $statement) = @proof_statements[$proof_int].kv;
          if $statement ~~ Assertion {
            my $assumption_count = $statement.assumptions.elems;
            my @by = @stack.splice(*-$assumption_count);
            my @assumptions = @!proof_steps[@by]»[0];
            @!proof_steps.push(($statement.substitute(@assumptions),
              (@by «+» 1).append($label)));
          } else {
            @!proof_steps.push(($statement.statement, [$label]));
          }
          @stack.push(@!proof_steps.elems - 1);
        }
      }
    }
  }

  method substitute(@assumptions) {
    my %substitutions;
    for @!assumptions».value Z @assumptions -> ($a, $b) {
      unless $a.essential {
        %substitutions{$a.var} = $b[1..*].Array;
      }
    }
    @!statement.map(-> $i {
      @(%substitutions{$i} // [$i])
    }).flat;
  }

  method essentials {
    @!assumptions».value.grep: { .essential }
  }

  method debug-print {
    print "  {$_.value.statement}\n" for @!assumptions;
    print "=>{@!statement}\n";
    return unless @!proof_steps;
    print "Proof\n";
    for 1..* Z @!proof_steps -> ($i, ($s, @b)) {
      print "  $i. $s (by {@b})\n"
    }
  }
}

class Actions {
  has Frame $.frame = Frame.new;
  has Assertion %.assertions;
  has Str $.latest_comment;

  has @.comments-and-assertions;

  method comment($/) {
    $!latest_comment = ~$/;
    @!comments-and-assertions.push(~$/);
  }

  method const($/) {
    $.frame.const.push(~«$<symbol>);
  }
  method var($/) {
    $.frame.var.push(~«$<symbol>);
  }

  method essential($/) {
    $.frame.hypotheses.push(~$<label> => Essential.new(
          statement => ~«$<symbol>));
  }
  method floating($/) {
    $.frame.hypotheses.push(~$<label> => Floating.new(
          type => ~$<type>, var => ~$<var>));
  }
  # TODO distinct

  method axiom($/) {
    my $assertion = Assertion.new(
        comment => $!latest_comment,
        frame => $!frame,
        statement => ~«$<symbol>);
    %!assertions{$<label>} = $assertion;
    @!comments-and-assertions.push($<label>);
  }
  method theorem($/) {
    my $assertion = Assertion.new(
        comment => $!latest_comment,
        frame => $!frame,
        statement => ~«$<symbol>,
        proof => $<proof>,
        previous_statements => %!assertions);
    %!assertions{$<label>} = $assertion;
    @!comments-and-assertions.push($<label>);
  }

  method push_fr($/) {
    $!frame = Frame.new(parent => $.frame);
  }
  method pop_fr($/) {
    $!frame .= parent;
  }
}

sub parse(Str $in) is export {
  my $actions = Actions.new;
  Parser.parse: $in, actions => $actions;
  $actions;
}

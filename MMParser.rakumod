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

# TODO document
sub decode_int(Str $encoded_int) {
  my $ret = 0;
  $encoded_int.comb(rx{
    | <[A..T]> { $ret = $ret * 20 + ord($/) - ord('A') }
    | <[U..Y]> { $ret = $ret *  5 + ord($/) - ord('T') } 
  });
  $ret;
}
# TODO move this test to a test file. Also, write a fucking test suite!
# Test for decode_int:
#   say qw/A B T UA UB UT VA VB YT UUA YYT UUUA/.map: &decode_int;
# should be
#   (0 1 19 20 21 39 40 41 119 120 619 620)

class ProofStep {
  has $.ref;
  has @.inputs;
  has $.expression;
}

class Assertion {
  has $.comment;
  has @.hypotheses;
  has @.statement;
  has ProofStep @.proof-steps;

  submethod BUILD(Str :$!comment, Frame :$frame,
                  :@!statement, :$proof, :%previous_statements) {
    my @frames = $frame.traverse.reverse;
    my @all_hypotheses = @frames».hypotheses».Slip.flat;

    my @symbols = @!statement;
    @symbols.append(.value.statement)
      for @all_hypotheses.grep: { $_.value.essential };
    @!hypotheses = @all_hypotheses.grep: {
      .value.essential or .value.var ∈ @symbols;
    }

    if $proof {
      # TODO uncompressed proofs
      self.decode_compressed_proof_steps(
        %(|@all_hypotheses, |%previous_statements), $proof);
    }
  }

  method decode_compressed_proof_steps(%previous_statements, $proof) {
    my @statements = $proof<label>
      ?? (%previous_statements{$proof<label>}:p)
      !! [];
    @statements.prepend(@!hypotheses);

    my @components = $proof<compressed>
      .subst(rx/<ws>/, :g)
      .comb(rx/<[U..Y]>*<[A..TZ]>/);
    my @stack = [];

    for @components {
      if $_ eq 'Z' {
        # Treat a "push" statement as if it's adding a new essential hypothesis.
        # TODO: There has got to be a better way to do that.
        @statements.push(
          "Step {@!proof-steps.elems}" =>
          Essential.new(statement => @!proof-steps[*-1][0].expression));
      } else {
        my ($label, $statement) = @statements[decode_int($_)].kv;
        if $statement ~~ Assertion {
          # Pop from the stack
          my @inputs = @stack.splice(*-$statement.hypotheses.elems);
          my @hypotheses = @!proof-steps[@inputs]».expression;

          my $new-statement = $statement.substitute(@hypotheses);
          @!proof-steps.push(ProofStep.new(
            ref => $label,
            inputs => (@inputs),
            expression => $new-statement));
        } else {
          @!proof-steps.push(ProofStep.new(
            ref => $label,
            expression => $statement.statement));
        }
        @stack.push(@!proof-steps.elems - 1);
      }
    }
  }

  method substitute(@hypotheses) {
    my %substitutions;
    for @!hypotheses».value Z @hypotheses -> ($a, $b) {
      unless $a.essential {
        %substitutions{$a.var} = $b[1..*].Array;
      }
    }
    @!statement.map(-> $i {
      @(%substitutions{$i} // [$i])
    }).flat;
  }

  method essentials {
    @!hypotheses.grep: { .value.essential }
  }

  method debug-print {
    print "  {$_.value.statement}\n" for @!hypotheses;
    print "=>{@!statement}\n";
    return unless @!proof-steps;
    print "Proof\n";
    for 1..* Z @!proof-steps -> ($i, ($s, @b)) {
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

use lib '.';
use MMParser;
use Mathify;
use Comments;

use template-compiler 'mm2html.template';

class ProofStepLite is ProofStep {
  has Int $.level;
}

sub proof-steps-lite(ProofStep @proof-steps) {
  my ProofStepLite @ret;

  sub pl-helper(Int $step-no, Int $level) {
    my ProofStep $step := @proof-steps[$step-no];
    next unless $step.expression[0] eq '|-';

    my Int @inputs = gather {
      for $step.inputs -> $i {
        take pl-helper($i, $level + 1);
      }
    }

    @ret.push: ProofStepLite.new(
      expression => $step.expression,
      inputs => @inputs,
      ref => $step.ref,
      level => $level,
    );
    @ret.elems;
  }

  pl-helper(@proof-steps.elems - 1, 0);
  @ret;
}

my $parsed = parse(slurp);

for $parsed.assertions.kv -> $label, $theorem {
  if $theorem.proof-steps {
    say $label;
    spurt "$label.html", proof-html(
      $theorem,
      proof-steps-lite($theorem.proof-steps));
  }
}

my @first100 = gather {
  # Gather everything that needs to appear on the first page, for now.
  # TODO: Get rid of kludge. There's a simple rule about headers between
  # theorems that works well here.
  # TODO: Rename $i
  my $kludge = False;
  my $i = 0;
  for $parsed.comments-and-assertions -> $comment-or-label {
    $kludge = True if $comment-or-label ~~ /"CLASSICAL FIRST-ORDER LOGIC WITH EQUALITY"/;
    next unless $kludge;
    if $comment-or-label ~~ /^<[\w._-]>+$/ {
      last if $i++ >= 100;
    }

    take $comment-or-label;
  }
}

spurt "index.html", index-page(@first100, $parsed.assertions);

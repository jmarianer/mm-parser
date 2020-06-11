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

spurt "index.html", gather {
  take q:to<EOF>;
    <html>
      <head>
        <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
        <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
        <script>
          window.MathJax = {
            loader: {load: ['[tex]/color']},
            tex: {packages: {'[+]': ['color']}}
          };
        </script>
        <style>
          /* TODO: This styling is pretty darn sucky. */
          body {
            margin-left: 100px;
            margin-right: 100px;
          }

          b {
            margin-left: 1.5em;
          }

          mjx-container {

            margin-left: 5em;
          }

          p mjx-container {
            margin-left: 0;
          }
        </style>
      </head>
      <body>
  EOF

  # TODO: Get rid of kludge. There's a simple rule about headers between theorems that works well here.
  # TODO: Rename $i
  my $kludge = False;
  my $i = 0;
  for $parsed.comments-and-assertions -> $comment-or-label {
    $kludge = True if $comment-or-label ~~ /"CLASSICAL FIRST-ORDER LOGIC WITH EQUALITY"/;
    next unless $kludge;
    if $comment-or-label ~~ /^<[\w._-]>+$/ {
      # Assertion
      last if $i++ >= 100;
      my $assertion = $parsed.assertions{$comment-or-label};
      take qq:to<EOF>;
        <p><b>Assertion <a href='$comment-or-label.html'>$comment-or-label\</a>.</b>
        {comment2html($assertion.comment)}</p>
        \\(
      EOF
      if $assertion.essentials {
        take $assertion.essentials.map({ mathify(.value.statement) })
              .join('\quad\&\quad');
        take '\quad\Rightarrow\quad';
      }
      take mathify($assertion.statement);
      take '\)';
    } else {
      # Comment
      take comment2htmlfoo($comment-or-label);
    }
  }
  take "</body></html>";
};


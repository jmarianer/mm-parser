use lib '.';
use MMParser;
use Mathify;
use Comments;

use template-compiler 'mm2html.template';

my $parsed = parse(slurp);

for $parsed.assertions.kv -> $label, $theorem {
  next unless $theorem.proof-steps;

  spurt "$label.html", proof-html($theorem)
}

spurt "output.html", gather {
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
      last if $i++ > 100;
      my $assertion = $parsed.assertions{$comment-or-label};
      take qq:to<EOF>;
        <p><b>Assertion <a href='$comment-or-label.html'>$comment-or-label\</a>.</b>
        {comment2html($assertion.comment)}</p>
        \\(
      EOF
      if $assertion.essentials {
        take $assertion.essentials.map({ mathify(.statement) })
              .join('\quad\&\quad');
        take '\quad\Rightarrow\quad';
      }
      take mathify($assertion.statement);
      take '\)';
    } else {
      # Comment
      take comment2htmlfoo($comment-or-label);
    }
# Proof steps take up too much MathJax power on the main page.
#    next unless $assertion.proof_steps;
#    for 1..* Z $assertion.proof_steps -> ($i, (@s, @b)) {
#      take "<tr><td>$i\</td><td>&nbsp;\\({mathify(@s)}\\) (by {@b})</td><tr>"
#    }
    
  }
  take "</body></html>";
};


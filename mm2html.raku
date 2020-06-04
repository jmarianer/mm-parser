use lib '.';
use MMParser;
use Mathify;
use Comments;

my $parsed = parse(slurp);


gather {
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
      </head>
  EOF
  for $parsed.assertions.kv -> $label, $assertion {
    take qq:to<EOF>;
      <p><b>Assertion $label.\</b>{comment2html($assertion.comment)}</p>
      \\(
    EOF
    if $assertion.essentials {
      take $assertion.essentials.map({ mathify(.statement) })
            .join('\quad\&\quad');
      take '\quad\Rightarrow\quad';
    }
    take mathify($assertion.statement);
    take '\)';
    next;
# Proof steps take up too much MathJax power on the main page.
    next unless $assertion.proof_steps;
    for 1..* Z $assertion.proof_steps -> ($i, (@s, @b)) {
      take "<tr><td>$i\</td><td>&nbsp;\\({mathify(@s)}\\) (by {@b})</td><tr>"
    }
    
  }
  take "</body></html>";
}.join("\n").print;


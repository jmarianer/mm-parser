my %tex-symbols =
  wff  => '{\rm\color{grey}wff\ }',
  '-.' => '\lnot',
  ph   => '{\color{blue}\varphi}',
  ps   => '{\color{blue}\psi}',
  ta   => '{\color{blue}\tau}',
  ch   => '{\color{blue}\chi}',
  th   => '{\color{blue}\theta}',
  et   => '{\color{blue}\eta}',
  '|-' => '\vdash',
  '->' => '\rightarrow',
  '<->'=> '\leftrightarrow',
  '('  => '\left(',
  # See https://tex.stackexchange.com/questions/36039/automatic-size-adjustment-for-nested-parentheses
  ')'  => '_{{}_{}}\right)',
;

sub mathify(@symbols) is export {
  "\\({ @symbols.map: {%tex-symbols{$_}} }\\)"
}

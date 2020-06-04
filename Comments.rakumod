use Mathify;

sub comment2html($comment) is export {
  my @para = $comment.split("\n\n");
  gather {
    for @para {
      take '<p>';
      .comb(rx {
          | '$('
          | '$)'
          | '_' (.+?) '_'              { take "<i>$0\</i>" }
          | '~' <ws> (<[\w._-]>+) <ws> { take $0 }
          | '`' (.+?) '`'              { take mathify($0.trim.split(' ')) }
          | (.)                        { take $0 }
          });
      take '</p>';
    }
  }.join();
}

use Mathify;

sub comment2html($comment) is export {
  my @para = $comment.split("\n\n");
  @para.map({
    gather {
      .comb(rx {
          | '$('
          | '$)'
          | '_' (.+?) '_'              { take "<i>$0\</i>" }
          | '~' <ws> (<[\w._-]>+) <ws> { take "$0 " }
          | '`' (.+?) '`'              { take '\(';
                                         take mathify($0.trim.split(' '));
                                         take '\)';
                                       }
          | (.)                        { take $0 }
          });
    }.join()
  }).join('</p><p>');
}

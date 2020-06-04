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

# TODO rename this sub
sub comment2htmlfoo($comment) is export {
  my $level = -1;
  if $comment ~~ rx {
    ^'$(' <ws> (
    | '####' { $level = 1 }
    | '#*#*' { $level = 2 }
    | '=-=-' { $level = 3 }
    | '-.-.' { $level = 4 }
    ) .*?\n (.*?) \n $0.*?\n (.*)$
  } {
    return "<h$level>$1\</h$level><p>{ comment2html($2) }</p>";
  }
}

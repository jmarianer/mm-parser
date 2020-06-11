grammar LineParser {
  rule TOP {
    | <tag><text>
    | <if>
    | <else>
    | <for>
    | <sub>
    | <use>
    | <!before <[<$]>><text>
  }

  rule tag {
    '<' $<tagname>=<ident> <attribute> * '>'
  }
  rule attribute { <ident> '=' <value> }
  rule value { '"' .* '"' }
  # TODO Support escaped quotes ([<[^"]> | '\"'] or somesuch)
  # TODO support `.class` and `#id` shorthands

  rule if {
    '$if' $<condition>=[.*]
  }
  rule else { '$else' }
  rule for {
    '$for' $<loop>=[.*]
  }

  rule sub { '$sub' $<name>=[<ident> [<['\-]> <.ident>]*] $<sig>=[.*] }
  rule use { '$use' $<name>=[.*] }

  rule text { .* }
}

class OpenActions {
  method tag($/) {
    take "take '<$<tagname> $<attribute>>';";
  }

  method text($/) {
    take qq/take "$/";/ if ~$/ ne '';
  }

  method if($/) {
    take "if $<condition> \{";
  }
  method else($/) {
    take 'else {';
  }
  method for($/) {
    take "for $<loop> \{";
  }

  method sub($/) {
    take "'&$<name>' => sub $<sig> \{ gather \{";
  }

  method use($/) {
    take "use $<name>;";
  }
}

class CloseActions {
  method tag($/) {
    take "take '</$<tagname>>';";
  }

  method if($/) {
    take '}';
  }

  method else($/) {
    take '}';
  }

  method for($/) {
    take '}';
  }

  method sub($/) {
    take '}.join },';
  }
}

class Nest {
  has Nest $.parent;
  has Str $.line;
  has Int $.indent;
  has Nest @.children;

  method generate-child {
    LineParser.parse($.line, actions => OpenActions);
    .generate-child for @.children;
    LineParser.parse($.line, actions => CloseActions);
  }

  method generate {
    gather {
      take '{';
      .generate-child for @.children;
      take '}';
    }
  }
}

sub EXPORT($template-file-name) {
  my Str $template = IO::Path.new($template-file-name).slurp;

  my Nest $stack = Nest.new(indent => -1);
  for $template.lines -> $line {
    $line ~~ /(<[\ ]>*)(.*)/;
    my Int $indent = $0.chars;
    $stack .= parent while $stack.indent >= $indent;
    my Nest $child = Nest.new(
      parent => $stack,
      line => ~$1,
      indent => $indent,
    );
    $stack.children.push($child);
    $stack = $child;
  }
  $stack .= parent while $stack.indent >= 0;

  my $raku-code = $stack.generate.join("\n");
  use MONKEY-SEE-NO-EVAL;
  my $output = EVAL $raku-code;

  $output;
}

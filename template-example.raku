use lib '.';
use template-compiler 'sample.template';

class Friend {
  has $.name;
  has $.age;
}

say some-method('Title', [Friend.new(name => 'Joey', age => 37)]);

say other-method;

use String::AntiString;
use feature qw(say);
use Carp::Always;

say "hello world" - " world" + " earth";
say "hi" - "i";
say -"hi" + "hi, there";

say (("hi" - "there" - "xyz")->representation);

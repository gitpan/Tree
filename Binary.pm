# Actually, this is a combination tree and chain.

# $node = Node::leaf(key, value, left, right, next, prev);
# $node->key;
# $node->value;
# $node->query(key);
# $node->insert(key, value);
# $node->is_empty;
# $node->left;
# $node->right;

# $node->_link

package Tree::Binary::Node;
use strict;
use Carp;
# use Truth;

sub _TRUE  { 1==1 }
sub _FALSE { !_TRUE }

# Node data members.
my ($KEY, $VALUE, $SPECIAL, $LEFT, $RIGHT, $NEXT, $PREV) 	= ( 0..6 );
my (@FIELDS) 			= ($KEY, $VALUE, $SPECIAL, $NEXT, $PREV);
my (@RELATIVES)		= ($LEFT, $RIGHT);

# Create an empty leaf.
sub leaf ($;$$$$) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my ($key, $value, $next, $prev) = @_;
  
  my $self = [];
  
  $self->[$KEY]		= $key;
  $self->[$VALUE]	= $value;
  $self->[$NEXT]	= $next;
  $self->[$PREV]	= $prev;
  
  bless $self, $class;
  return $self;
}


# Return true if the tree is empty.
sub is_empty { !defined shift->[$KEY]; }

sub key 	{ shift->[$KEY]; }
sub value 	{ shift->[$VALUE]; }

# Compare values with keys
# PRIVATE FUNCTIONS
sub lt  ($$) {my $self = shift; $self -> CMP (@_, $self -> [$KEY]) <  0;}
sub le  ($$) {my $self = shift; $self -> CMP (@_, $self -> [$KEY]) <= 0;}
sub eq  ($$) {my $self = shift; my $key = shift;  print STDERR "$key eq $self->[$KEY]\n"; $self -> CMP ($key, $self->[$KEY]) == 0;}
sub ge  ($$) {my $self = shift; $self -> CMP (@_, $self -> [$KEY]) >= 0;}
sub gt  ($$) {my $self = shift; $self -> CMP (@_, $self -> [$KEY]) >  0;}
sub cmp ($$) {my $self = shift; $self -> CMP (@_, $self -> [$KEY]);}
# If you want some other order, mask this function:
sub CMP ($$) {print STDERR "CMP $_[1] and $_[2]\n";  $_[1] cmp $_[2];}


# $tree -> insert (key, value);
# value == undef is fine.
sub insert {
  my $self  = shift;
  my ($key, $value)  = @_;

  print STDERR "Checking $self to add $key/$value\n";
  
  my $is_new;
  if ( $self -> is_empty || $self->eq($key) ) {
    $self ->[$KEY]   	= $key;
    $self ->[$VALUE] 	= $value;
    $self ->[$LEFT]  	= $self -> leaf ();
    $self ->[$RIGHT] 	= $self -> leaf ();

    print STDERR "Added $key/$value to $self\n";

    return $self;
  }

  # Recurse.
  my $newNode = $self -> [$self->lt($key) ? $LEFT : $RIGHT] -> insert ($key, $value);
  
  if ( ref $newNode ) {
    if ($self->[$LEFT] == $newNode) {
      $self->[$PREV]->[$NEXT] = $newNode if $self->[$PREV];
      $newNode->[$NEXT] = $self;
      $newNode->[$PREV] = $self->[$PREV];
      $self->[$PREV] = $newNode;
      
      print STDERR $self->key, "Prev: ",$self->[$PREV]->key if $self->[$PREV];
      print STDERR $self->key, "Next: ",$self->[$NEXT]->key if $self->[$NEXT];
      print STDERR $newNode->key, "Prev: ",$newNode->[$PREV]->key if $newNode->[$PREV];
      print STDERR $newNode->key, "Next: ",$newNode->[$NEXT]->key if $newNode->[$NEXT];
      print STDERR "\n;"
    }
    else {			# $self->[$RIGHT] == $newNode
      $self->[$NEXT]->[$PREV] = $newNode if $self->[$NEXT];
      $newNode->[$PREV] = $self;
      $newNode->[$NEXT] = $self->[$NEXT];
      $self->[$NEXT] = $newNode;
      print STDERR $self->key, "Prev: ",$self->[$PREV]->key if $self->[$PREV];
      print STDERR $self->key, "Next: ",$self->[$NEXT]->key if $self->[$NEXT];
      print STDERR "Prev: ",$newNode->[$PREV]->key if $newNode->[$PREV];
      print STDERR "Next: ",$newNode->[$NEXT]->key if $newNode->[$NEXT];
      print STDERR "\n";
    }
  }

  return _TRUE;
}


# Given a key, return the value. undef if not found.
sub query ($$) {
  my $self = shift;
  my $key  = shift;

  print STDERR "Querying $self for $key\n";
  
  return undef if $self->is_empty();
  return $self if $self->eq($key);
  
  return $self -> [$self -> lt ($key) ? $LEFT : $RIGHT ] -> query($key);
}


sub tree_maximum {
  my $self = shift;
  return $self->[$RIGHT]->is_empty() ? $self : $self->[$RIGHT]->tree_maximum;
}


sub tree_minimum {
  my $self = shift;
  print STDERR "Finding minimum of $self, ", $self->key, "\n";
  return $self->[$LEFT]->is_empty() ? $self : $self->[$LEFT]->tree_minimum;
}


sub tree_successor {
  my $self = shift;
  my ($key) = @_;
  
  return $key ? $self->query($key)->[$NEXT] : $self->[$NEXT];
}


sub tree_predecessor ($$) {
  my $self = shift;
  my $key  = @_;
  
  return $key ? $self->query($key)->[$PREV] : $self->[$PREV];
}


sub _copy_fields {
  my $self = shift;
  my ($other) = @_;
  
  map {$self->[$_] = $other->[$_];} @FIELDS;
}


sub _copy_relatives {
  my $self = shift;
  my ($other) = @_;
  
  map {$self->[$_] = $other->[$_];} @RELATIVES;
}


# 0 returns the left node.
# 1 returns right.
sub _link ($$) {
	return shift->$RELATIVES[shift];
}


sub delete ($$) {
  my $self = shift;
  my ($key)  = @_;
  
  return 0 if $self -> is_empty (); # Key isn't there.
  
  # If unequal, go into recursion.
  return $self -> [$LEFT]  -> delete ($key) if $self -> lt ($key);
  return $self -> [$RIGHT] -> delete ($key) if $self -> gt ($key);
  
  # So now we have to delete this node.
  # Easy cases, we only have one kid.
  if ( $self->[$RIGHT]->is_empty ) {
    $self->_copy_fields($self->[$LEFT]);
    $self->_copy_relatives($self->[$LEFT]);
    return _TRUE;
  }
  if ( $self->[$LEFT]->is_empty ) {
    $self->_copy_fields($self->[$RIGHT]);
    $self->_copy_relatives($self->[$RIGHT]);
    return _TRUE;
  }
  # Else, both subtrees are filled. Find the maximum of the right subtree.
  my $max = $self -> [$RIGHT] -> tree_maximum ();
  
  # Copy the content, but not the structure.
  $self -> _copy_fields ($max);
  
  # Delete the maximum.
  $max -> delete ($max -> [$key]);
  
  return _TRUE;
}


sub keys {
  my $self = shift;
  my ($lowerKey, $upperKey) = @_;
  
  return undef if $self->is_empty;

  print STDERR "Keying $self\n";
  
  my @keys;
  unless ( defined $lowerKey && $self->le($lowerKey)  ) {
    @keys = $self->[$LEFT]->keys;
  }
  push @keys, $self->key;
  print STDERR "Keys are ", @keys, " so far\n";
  unless ( defined $upperKey && $self->ge($upperKey) ) {
    push @keys, $self->[$RIGHT]->keys;
  }
  
  return @keys;
}


sub values {
  my $self = shift;
  my ($lowerKey, $upperKey) = @_;
  
  return undef if $self->is_empty;
  
  my @values;
  unless ( defined $lowerKey && $self->le($lowerKey)  ) {
    @values = $self->[$LEFT]->values;
  }
  push @values, $self->value;
  unless ( defined $upperKey && $self->ge($upperKey) ) {
    push @values, $self->[$RIGHT]->values;
  }
  
  return @values;
}


# <deth metal>DEEEEESTRRRROOOOOY!</deth metal>
# Break the chain to remove structure circularity and let Perl's GC do its yob.
sub DESTROY {
  my $self = shift;
  print STDERR "Destroying $self:",$self->key,"\n";
  return if $self->is_empty;
  $self->[$RIGHT]->DESTROY;
  $self->[$LEFT]->DESTROY;
  $self->[$PREV] = undef;
  $self->[$NEXT] = undef;
}


return _TRUE;

### HERE THERE BE PODS ###
=head1 DESCRIPTION
  
  A virtual class used to build a virtual forest of Trees (yuk yuk).

=head1 SYNOPSIS or See the Trees for the Forest

  $myTree = new Tree::MyTree;		# Create a new tree of type MyTree
  $myTree->insert('key', 'value');	# Add a new key/value pair.
																		# or change an existing one.
  $myTree->delete('key');			# Delete a key/value pair
  $value = $myTree->find('key');	# Find the value of a key
  $myTree->exists('key');			# Does the given key exist?
  $myTree->clear;						# Delete the entire tree.
  @sortedKeys 	= $myTree->keys([lowerKey],[upperKey]);
  @sortedValues = $myTree->values([lowerKey], [upperKey]);

  # Works kinda like each().
  ($key, $value)	= $myTree->next([key]);
  ($key, $value)	= $myTree->prev([key]);
  $myTree->reset;			# Resets the default key used
											# for next() and prev()
								
  ($key, $value)  = $myTree->least;
  ($key, $value)	= $myTree->greatest;

  $myTree->debug(level);		# Sets the debugging level
  # UNIMPLEMENTED
  $myTree->sortby(&cmp);		# Sets how the tree is sorted
  # UNIMPLEMENTED

=head1 EFFICIENCIES or Be a Tree Hugger.

  Tree methods vs. their hash equivelents.
  (Orders are average and for a balanced tree.  Orders given in []'s 
  are for Splay trees using a commonly accessed key, or in {}'s are for 
  BTrees with a sufficiently high B.  These are only shown if different.)

  $myTree 	= new MyTree;	# O(1)
  (%myHash = ();)				# O(1)
	
  $myTree->insert(key, value);# O(logn)
  ($myHash{key} = value;)	# O(1)
	
  $myTree->delete(key);		# O(logn) [ O(1) ]
  (delete $myHash{key};)	# O(1)
	
  $myTree->find(key);		# O(logn) [ O(1) ]
  ($myHash{key};)				# O(1)
	
  $myTree->exists(key);		# O(logn) [ O(1) ]
  (exists $myHash{key};)	# O(1)
	
  $myTree->clear;			# O(n)  	As a result of the internal chaining,
  										#	each node in the tree must be unlinked
  										#	manually to prevent memory leaks.
  (%myhash = undef;)		# O(1)
	
  $myTree->keys([lowerKey], [upperKey]); # O(n)
  (sort keys %myHash;)		# O(nlogn)
	
  $myTree->values([lowerKey], [upperKey]); # O(n)
  (foreach $key (sort keys %myHash) { # O(nlogn)
     push @values, $myHash{$key};
   }  )
	
  $myTree->next([key]);		# O(1), O(logn) if key is 
													# given
  (something... (sort keys %myHash);) # O(nlogn)
	
  $myTree->prev([key]);		# same as next
	
  $myTree->reset;				# reset the state of the tree
  (can't do it)
  
  $myTree->least;						# O(logn)
  ((sort keys %myHash)[0];)	# O(nlogn)
  $myTree->greatest;				# same as least
  (pop(sort keys %myHash);)	# same as least
  
  So as you can see, if you ever find yourself sorting a hash, use a tree.
  
=cut

### END OF PODS ###
  
package Tree::Base;
  
use vars qw($VERSION);

# Our hooks for tying.  Most of these will simply be aliases.
use subs qw(TIEHASH FETCH STORE DELETE EXISTS FIRSTKEY NEXTKEY
						CLEAR DESTROY);

BEGIN {
  $VERSION		= 0.001;	   # Pre-alpha, first draft, NO GUARENTEES!
  									# Ewe half-bean worned!
}

use strict;
use Carp;

# A note about the internal data structure of our trees:
#		Two things.  One: I decided to use hashes rather than arrays for
#	simplisity's sake.  Using arrays requires that I keep an array of
#	named constants like ($KEY, $VALUE) = (0..1); around.  This is difficult
#	to pass to inheriting classes.  Furthermore, by the time this module is
#	ready for production, constant hash aliasing to array will hopefully be
#	completed.  ("Luke, trust your compiler!")
#		Two:  Ummm... shit, I forgot.
#
# More notes to self:
# For a decently balanced tree (or fixed height, such as a BTree) might it be
# worth it to do have each level of the tree represented as a single AV?
# ie:
#
# 0:						@tree[0] = (\$root);
# 1:				@tree[1] = (\$leftChild, \$rightChild);
# 2:	@tree[2] = (\$1stGChild, \$2ndGChild, etc...);
#
# Hmm, maybe not.
#
# NOTE:  When dealing with the initial/null case of a tree (no nodes/keys)
# rather than checking to see if $self->{_tree} is defined, I should probably
# have a special null case for a node, so that methods can be called on it,
# but they will simply return false (undef, whatever).
# Actually, strike that.  I've got the wrapping class for the tree's nodes, so
# why not use it?  It makes life simpler to just check if the tree is defined,
# and the method of having empty nodes hanging off the leaves of the tree is
# just a big waste of memory.
#
# More notes:  I should probably have a Tree::Base::root() accessor
# method.

# $myTree = Tree::Base->new(key1, value1, key2, value2, etc...);
# or $myTree = Tree::Base->new(%hash);
# or $myTree = Tree::Base->new(key1 => value1, key2 => value2, ...);
sub new {
  my $proto 	= shift;
  my $class	= ref($proto) || $proto;
  
  my $self = {};

  $self->{_tree} 			= undef;  	# The root of our tree.
  $self->{_state}			= undef;  # The last node accessed via next() or
  															# prev().  Used when performing
  															# traversals.
#  $self->{_numNodes} = 0;   	# A count of the size of the tree.
															# too much trouble to implemenet right now
															# for far too little return.  Maybe later.
	# I could add these without too much trouble... but I don't think its
	# worth adding the overhead to every insert() and delete() for the sake
	# of saving a log(n)'s worth of work during keys() and values(), which are
	# O(n) anyway, so it won't matter much.
#  $self->{_maxNode}  = undef;  # The largest node in our tree.
#  $self->{_minNode}	 = undef;  # and the smallest.
  
  bless($self, $class);
  
  $self->insert(@_);
  
  return $self;
}



sub insert {
  my( $self ) = shift;
  
	while(@_) {
		$self->_insert(shift, shift);
	}
  
  return 1;
}


# A simple binary insertion w/o balancing.
# Shows the bases that an overloaded function need to cover.
sub _insert {
  my( $self, $key, $value ) = @_;

  my $foundNode;  # The node found by query().  Remember, its either a
  								# leaf or the exact node we're lookign for.
  my $newNode;	# The new node to be inserted.
  
  if( defined ($foundNode = $self->_root->query($key)) ) {
  	my $cmp = $foundNode->cmp($key);  # To save us two comparisons.
  	
		unless( $cmp ) {  # The node already exists.
			# Just replace its value with the new one.
			$foundNode->value($value);
		}
		else {  # hang the node off of the leaf we found.
			$newNode = $self->new($key, $value);
			
			if( $cmp == 1 ) { # key's greater than this node.
				# Hang our new node off the right.
				$foundNode->most($newNode);
				$foundNode->addToChain($newNode);
			}
			elsif( $cmp == -1 ) { # key's less.
				# Hang off the left branch.
				$foundNode->least($newNode);
				$foundNode->addToChain($newNode);
			}
			else { croak("Bad return from ", ref $self, "::cmp.  $cmp"); }
		}
	}
	else {  # Tree's empty, this is the new node.
		$self->_root(Tree::Base::Node->new(@_));
	}
	
	return 1;
}

# It goes like this.  _query() finds a node, _find() returns that node only
# if its the one we're really looking for and find() returns only its value.
# find() uses _find() uses _query().  Building blocks.  I love it!  More fun
# than Lincoln Logs.

# The public find method.  Analagous to $hash{$key};
# All it really does is call _find and return
# only its value.
sub find {
	my $node = shift->_find(@_);
	return defined $node ? $node->value : undef;
}

# Why have three find methods?  Why not just use
# Tree::Base->_root->find() instead of Tree::Base->_query()?  Take a look at
# Tree::Smart::Node.  No find method.  You can't be guarenteed that a given
# tree type will know how to find each other.  Only the tree as a whole can
# be guarenteed to do that.  Also, this way only _query() needs to be
# overridden by subclasses.

# A private find method.  This returns the entire node, not just its value.
sub _find {
	my $node = shift->_query(@_);
	return defined $node && $node->eq(@_) ? $node : undef;
}

# A private method, one which returns the node found and not just its key.
# It also doesn't make any checks if this is the proper node we were
# looking for. Methods should use this if you find yourself needing to call
# the Node's find() method directly, for inheritance purposes.
# Things like next() and prev() use this.
sub _query {
	my $self = shift;
	return defined $self->_root ? $self->_root->find(@_)
															: undef;
}


sub delete {
	croak(ref $_[0], " forgot to overload Tree::Base::delete(), you ninny!");
}


# I don't like the redundancy between next() and prev().  I'd like to
# somehow merge the two.
sub next {
  my $self	= shift;
	my $nextNode;  					# The next node
	my($nextKey, $nextValue);   # The key and value of the next node.

  # If a key is given, find its successor, else use the state's.
  # If there's no state, return the minimum.
  # Set state and return the next key/value.
	if( !@_ ||													# no key, use the state. 
			(defined $self->{_state} &&			# or the key is the state.
				$self->{_state}->eq(@_)	)  	)
	{ 
		if( defined $self->{_state} ) { 
			$nextNode = $self->{_state}->next;
		}
		else {
			$nextNode = $self->_least;
		}
	}
	elsif(@_ == 1) {
		my $tmpNode = $self->_query(@_);
		
		# If _query() returned the node we're looking for, or one less than
		# that, we use its successor.  Otherwise, _query() found our successor
		# already.
		$nextNode = $tmpNode->le(@_) 	? $tmpNode->next
										 							: $tmpNode;
	}
	else {
		croak("Too many arguments for ", ref $self,"::next().\n",
					q|Usage:  $tree->next([key]).|);
	}
	
	# Remember the new state.
	$self->{_state} = $nextNode;
	
	if( defined $nextNode ) {
		$nextKey 		= $nextNode->key;
		$nextValue 	= $nextNode->value;
	}
	
	return wantarray 	? ($nextKey, $nextValue)
										: $nextKey;
}


sub prev {
  my $self	= shift;
	my $prevNode;  					# The previous node
	my($prevKey, $prevValue);   # The key and value of the previous node.

  # If a key is given, find its predecessor, else use the state's.
  # If there's no state, return the maximum.
  # Set state and return the previous key/value.
	unless(@_) { # no key, use the state.
		if( defined $self->{_state} ) { 
			$prevNode = $self->{_state}->prev;
		}
		else {
			$prevNode = $self->_greatest;
		}
	}
	elsif(@_ == 1) {
		my $tmpNode = $self->_query(@_);
		
		# If _query() returned the node we're looking for, or one greater than
		# that, we use its predecessor.  Otherwise, _query() found our pred.
		# already.
		$prevNode = $tmpNode->ge(@_) 	? $tmpNode->prev
										 							: $tmpNode;
	}
	else {
		croak("Too many arguments for ", ref $self,"::prev().\n",
					"Usage:  \$tree->prev([key]).");
	}
	
	# Remember the new state.
	$self->{_state} = $prevNode;
	
	if( defined $prevNode ) {
		$prevKey 		= $prevNode->key;
		$prevValue 	= $prevNode->value;
	}
	
	return wantarray 	? ($prevKey, $prevValue)
										: $prevKey;
}
	  
				
# Clear the state of the tree
sub reset {
  shift->{_state} = undef;
  return 1;
}


sub exists {
	return defined shift->_find(@_) ? 1 : 0;
}


sub clear {
  my $self = shift;
  $self->reset;
  $self->DESTROY;

  return 1;
}


# keys() and values() will accept an upper and/or lower bound.  Thus...
# keys('this', 'that') returns only those keys which are less than or
# equal to 'that' and greater than or equal to 'this'.  values(undef, 'foo')
# returns all values whose keys are less than 'foo'.
sub keys {
	return shift->_traverse('key', @_);
}

sub values {
	return shift->_traverse('value', @_);
}


# Performs a traversal of the tree from the given low key to a given
# highest (or just from the beginning to end).  It performs a given
# function on each node found.  This is the building block for keys()
# and values().
sub _traverse {
	my(	$self, 
			$method,  	# A method to perform upon each node before storing.
								# Shouldn't take any arguments.  Its return value is
								# stored.  
			$lowKey, 					# The lower and
			$highKey) = @_;		# upper bounds of our search.
	
	my $rMethod;  # a code ref to $method.
	
	return () unless defined $self->_root;
	
	# Check to make sure the given method exists and get a reference to it.
	# This also allows inheritance to run its course.
	unless( defined( $rMethod = $self->_root->can($method) ) ) {
		croak(ref $self->_root, "::_traverse() was given an invalid method name '$method'");
	}
	
	# We're going to be accessing it alot, so let's remove the hash overhead.
	my($tree) = $self->_root;  
	
	my($currNode, $currKey);   # The current node and key being looked at.
	my @nodes;   	# Our list of nodes after they've had the appropriate
								# method performed on them.	

	if( defined $tree ) {
		#--- This doesn't seem to work.  Rats. ---#
	  # Miracle-Gro our node list to prevent unnecessary reallocation.
	  # Not all trees keep track of their number of nodes, BTW.
	  #if( defined $self->{_numNodes} &&
	  #		!(defined $lowKey || defined $highKey) ) 
	  #{
		#	$#nodes = $self->{_numNodes} - 1;
		#}
		#-----------------------------------------#
		
		# Find the lowest node in our search.
		if( defined $lowKey ) {
			# Set our current node to the low key... or something close.
			$currNode = $self->_query($lowKey);
			
			# We want to start either at the low key, or if that key doesn't
			# exist, we start at the key which would come after it (if it existed)
			$currNode = $currNode->next if $currNode->lt($lowKey);
		}
		else {
			$currNode = $self->_least;
		}
		
		# We simply follow our little chain until either we run out of tree
		# or we pass our upper bound.
		for( 	;	
					defined( $currNode ) &&
						!(defined $highKey && $currNode->gt($highKey));
					$currNode = $currNode->next ) 
		{
			# Remember, $rMethod is a method reference.  &$rMethod($currNode) should
			# be equivalent to $currNode->Method where $rMethod = \&Method;
			push(@nodes, &$rMethod($currNode));
		}
	}
	# nothing else.
	
	return @nodes;
}


# Accessor method to read/set the root of the tree.
sub _root {
	$_[0]->{_tree} = $_[1] if @_ == 2;
	return $_[0]->{_tree};
}


sub _least {
	return $_[0]->_root->minimum;
}

sub _greatest {
	return $_[0]->_root->maximum;
}


sub least {
	my $minimum = $_[0]->_least;
	
	return wantarray 	? ($minimum->key, $minimum->value)
										: $minimum->key;
}

sub greatest {
  my $maximum = $_[0]->_greatest;
	
	return wantarray 	? ($maximum->key, $maximum->value)
										: $maximum->key;
}


# List all relatives of a node, for debugging.
sub _relatives {
  my $self = shift;
  my ($key) = @_;
  my $node = $self->_root->query($key);
  if( defined $node ) {
  	print STDERR 	"Key:  ", $node->key,
  								" Value:  ", $node->value,
  								" Prev:  ", $node->prev->key, 
  								" Next:  ", $node->next->key, "\n";
  }
  
  return defined $node ? 1 : undef;
}


# Because these aren't really just trees, its also a chain (so next()
# and prev() are O(1)) that means we've got a circular data structure!
# AHHHHHHHHHHHH!!!  Bane to garbage collection routines everywhere.
# Its simple enough to bust up, just undef each node's previous link
# as we walk down the chain, thus turning it into a normal linked list,
# which GC can cope with.
# Acutally, its not quite that simple.  The whole chain/linked list
# has to be busted up completely because, normally the whole thing
# that sets the GC into motion is undef'ing our reference to the
# root node.  Because of the chain/linked-list the nodes preceding and
# following the root node still point to it, thus no GC.  So the whole
# chain has to be completely broken, not just turned into a linked-list.
#
# Someone please improve on this.
sub DESTROY {
	my($self) = shift;
	
	my($node, $nextNode);
	
	for( 	$node = $self->_least,  $nextNode = $node->next;
				defined $nextNode;
				$node = $nextNode,  $nextNode = $nextNode->next ) 
	{
		$node->prev(undef);
		$node->next(undef);
	}
	
	$self->_root(undef);
}


# Hooks for tying.
sub TIEHASH { return shift->new(@_); }
sub FETCH   { return shift->find(@_); }
sub STORE   { return shift->insert(@_); }
sub DELETE	{ return shift->delete(@_); }
sub EXISTS	{ return shift->exists(@_); }

sub FIRSTKEY	{ 
	my $self = shift;
	$self->reset;
	return $self->next;
}

# Since we save state, we don't need to even look at the argument
# that the tie mechanism passes.  So rather than use next() and have to
# rely on all sorts of special argument processing to deal with the fact
# that the argument passed is the same as the state, we'll write a quick
# wrapper.
sub NEXTKEY {
	return $_[0]->next;
}

sub CLEAR 	{ return shift->clear(@_); }


#####################################################################
# Tree::Base::Node
# The virtual base class for building more trees.
#####################################################################
package Tree::Base::Node;

use subs qw(least most);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my ($key, $value, $left, $right, $next, $prev) = @_;
	
	my $self = {
					'key' 	=> 	$key,
					'value'	=> 	$value,
					'next'	=> 	$next,	# The next node in order
					'prev'	=>	$prev,	# the previous one.
					'left'	=> 	$left,	# Its lower child
					'right'	=>	$right	# Its greater one
					};
					
	bless $self, $class;
	return $self;
}


# This will only work for binary search trees.
#
# if find() fails to find the specified node, it should return whatever
# the last node it visits is anyway.  This node is usually the one
# before or after where the key we were looking for should be.
sub find {
	my($self, $key) = @_;

	my $link = $self->link($self->gt($key));

	# RECURSION TERMINATION #1.  Either we've found it, or we've run
	# out of tree.
	if( $self->is_leaf || $self->eq($key) || !defined $link) {
		return $self;
	}

	# recurse.
	return $link->find($key);
}


# As it says, you should just overload these methods.
sub insert {
	croak( ref $_[0], " forgot to overload Tree::Base::Node::insert() you ninny!");
}

sub delete {
	croak( ref $_[0], " forgot to overload Tree::Base::Node::delete() you ninny!");
}


# Like I said, these trees are also chains.  That's what allows us to
# accomplish O(n) each() when used as a tied hash.  addToChain() and
# removeFromChain() do just that.  When a node is inserted or deleted they
# must be added or removed from the chain as well as "simply" put into the
# tree.  See Tree::Base::insert() for an example of their use.
sub addToChain {
	my(	$self, 
			$newMiddleNode    # The node to be added to the chain.
		) = @_;
		my $followingNode;

	# A simple double-linked list insertion.
	if( $self->lt($newMiddleNode) ) {
		$followingNode = $self->next;
		$newMiddleNode->prev($self);
		$newMiddleNode->next($followingNode);
		$self->next($newMiddleNode);
		$followingNode->prev($newMiddleNode) if defined $followingNode;
	}
	else {  # the new node is less than we are.
		$followingNode = $self->prev;
		$newMiddleNode->next($self);
		$newMiddleNode->prev($followingNode);
		$self->prev($newMiddleNode);
		$followingNode->next($newMiddleNode) if defined $followingNode;
	}
	
	return 1;
}

sub removeFromChain {
	my($self) = @_;   # remove ourself from the chain.
	
	# To avoid calling pred() and succ() twice, we store their results.
	my($myPred) = $self->prev;
	my($mySucc) = $self->next;

	# A simple double-linked list deletion.
	$myPred->next($mySucc) 	if defined $myPred;
	$mySucc->prev($myPred) if defined $mySucc;

	return 1;
}


# Accessor methods for binary children.  Non-binary tree methods and
# methods which are usable for both binary and non-binary trees should
# use most(), least() or link() rather than these.
sub left {
	$_[0]->{left} = $_[1] if @_ == 2;
	return $_[0]->{left};
}

sub right {
	$_[0]->{right} = $_[1] if @_ == 2;
	return $_[0]->{right};
}

# Use then when writing generic methods such as maximum & minimum.
# ie.  For most search trees, you find the smallest node by simply
# traversing towards the smallest child.  So rather than use left() use
# least() and it will work for most any tree (provided they properly
# overrode least() and most()).  See minimum() and maximum() below.
*least 	= 	\&left;
*most 	= 	\&right;


# I can't think of a good reason why you would have to change the
# key after creation.
sub key {
	return $_[0]->{'key'};
}

sub value {
	$_[0]->{value} = $_[1] if @_ == 2;
	return $_[0]->{'value'};
}


sub is_leaf {
	# check if there are any children
	foreach ($_[0]->children) {
		if( defined $_ ) { return 0; }
	}
	return 1;
}

sub is_empty {
	return defined $_[0]->{'key'};
}


sub prev {
	$_[0]->{'prev'} = $_[1] if @_ == 2;
	return $_[0]->{'prev'};
}

sub next {
	$_[0]->{'next'} = $_[1] if @_ == 2;
	return $_[0]->{'next'};
}


# recursive walk towards the smallest key
sub minimum {
	my($self) = shift;
	unless( defined $self->least ) {
		return $self;
	}
	else {
		return $self->least->minimum;
	}
}


# recursive walk towards the largest key
sub maximum {
	my($self) = shift;
	unless( defined $self->most ) {
		return $self;
	}
	else {
		return $self->most->maximum;
	}
}


# Access method to the links (children) of a node.  $linkNum is which
# child is being refered to, 0 is the smallest (left in the binary 
# case) up to whatever (B - 1 in the BTree case, or 1 for the right
# node in the binary case which is presented here.
sub link {
	my($self, $linkNum, $node) = @_;
	
	if( @_ == 3 ) {
		return $linkNum ? $self->{'right'} 	= $node 
										: $self->{'left'} 	= $node;
	}
	else {
		return $linkNum ? $self->{'right'}
										: $self->{'left'};
	}
}


# Return all children (links) of this node, from smallest to largest.
sub children {
	return ($_[0]->left, $_[0]->right);
}

	
# Override THIS method to change the sorting of the tree, 
# not lt or eq, etc...
# I should probably make this smart enough to differenciate between
# strings and numbers by default.  For now, its string sorting.
#
# For further flexibility, I've decided that cmp() and its dependent
# comparision methods (lt, eq, etc...) will take a node as an argument
# instead of just the key.  This allows for sorting by value, rather
# than by key, if that is your wont.
#
# Maybe I should just use overload... but I hear its not too pleasently
# implemented yet.
sub cmp {
	# my($self, $node) = @_;  # Removed for speed
	return ref $_[1] 	? $_[0]->key cmp $_[1]->key
										: $_[0]->key cmp $_[1];
}

# These should return 1 or 0 for the sake of binary trees.
# eq, ge, gt, etc...
# BTW, think of $self->lt($node) as $self lt $node.  That's how I keep things
# straight.
sub lt {
	#	my($self, $node) = @_;  # removed for speed
	return $_[0]->cmp($_[1]) == -1 	? 1 : 0;
}

sub le {
	#	my($self, $node) = @_;  # removed for speed
	return $_[0]->cmp($_[1]) <= 0  	? 1 : 0;
}

sub eq {
	#	my($self, $node) = @_;  # removed for speed
	return $_[0]->cmp($_[1]) == 0		? 1 : 0;
}

sub ge {
	#	my($self, $node) = @_;  # removed for speed
	return $_[0]->cmp($_[1]) >= 0		? 1 : 0;
}

sub gt {
	#	my($self, $node) = @_;  # removed for speed
	return $_[0]->cmp($_[1]) == 1		? 1 : 0; 
}

# For debugging purposes only.
sub DESTROY {
	print "RIP:  ",shift->key,"\n";
}
return 1;

package Tree::Smart;

use vars qw(@ISA $VERSION);

BEGIN {
	@ISA = qw(Tree::Base);
	$VERSION = 0.01;
}

use Tree::Base;

use Carp;
use strict;


=head1 DESCRIPTION

   An implementation of Binary Splay Trees, a tree that 'learns' which
   keys you use most often and improves its performance.
   
=head1 SYNOPSIS

	See Tree::Base.
		
=cut



sub _splay {
	my($self, $key) = @_;
	
	# Perform a top-down splay.  Splay one, perl two.
	my($newRoot, $storage) = 
		$self->_root->_splay($key, Tree::Smart::Storage->new); 	
	
	# All of Perl's hashes and all of Perl's mem,
	# put the splay tree back together again.
	$storage->hang('left',  $newRoot->left) if defined $newRoot->left;
	$storage->hang('right', $newRoot->right) if defined $newRoot->right;
	$newRoot->left($storage->left);
	$newRoot->right($storage->right);
	
	# The root of the tree is now the node we were looking for... or the
	# closest thing.  Also, the tree is now shuffled and balanced-ish.
	$self->_root($newRoot);
	
	return $newRoot;
}


# Wow, that's way too simple.
# Just splay for a given key and return the new root.  Let SUPER::_find() and
# SUPER::find() figure out if we found what we're looking for.
sub _query {
	my( $self ) = shift;
	return $self->_splay(@_);
}


sub _insert {
	my($self, $key, $value) = @_;
	
	my($newNode);  # The new node being inserted.
	
	if( defined $self->_root ) {
		$self->_splay($key);
	
		my($cmp) = $self->_root->cmp($key);
	
		# The key to be inserted already exists, so we just overwrite its value.
		if( $cmp == 0 ) {
			$self->_root->value($value);
		}
		
		# Otherwise, we make the new inserted node root.
		else {
			my $dir = $cmp > 0;  # Is our new node greater or less than the
										# current root?
			$newNode = Tree::Smart::Node->new($key, $value);
			
			# Make the old root a child of our new node, in the current place,
			# and the new node takes the old root's opposite child (if root is on
			# new's right, take root's left child and vice-versa)
			# And don't forget to remove the old root's link.
			$newNode->link($dir, $self->_root);
			$newNode->link(!$dir, $self->_root->link(!$dir));
			$self->_root->link(!$dir, undef);
			# The new node is our root now.
			$self->_root($newNode);
			# Add our new node to the chain.
			$dir 	? $newNode->right->addToChain($newNode)
					: $newNode->left-> addToChain($newNode);
					
			$self->{_numNodes}++;
		}
	}
	# First node, just plop it in.
	else {
		$newNode = Tree::Smart::Node->new($key, $value);
		$self->_root($newNode);
		$self->{_numNodes}++;
	}
	
	# Check to see if we have a new minimum or maximum.
	if( defined $newNode ) {
		if( !defined $self->{_minNode} || 
			 $self->{_minNode}->gt($newNode) ) 
		{
			$self->{_minNode} = $newNode;
		}
		# Yes, if.  On the case where this is the first node inserted, it will
		# be both the least and greatest.
		if( !defined $self->{_maxNode} ||
			 $self->{_maxNode}->lt($newNode) ) 
		{
			$self->{_maxNode} = $newNode;
		}
		# nothing else 
	}
		
	return 1;
}


# "Deletion from a splay tree is simply a matter of reversing these steps
#  after the desired node is located by Splay."  (Binstock & Rex, 1995)  HA!
#  If you believe that, I got a bridge in Brooklyn to sell ya.
sub delete {
	my($self, $key) = @_;
	
	if( defined $self->_root ) {
		$self->_splay($key);
		
		my $oldRoot = $self->_root;
		
		if( $oldRoot->eq($key) ) {
			my $newRoot;		# The new root node.
			# both children of the old root.
			my @rootChildren = $oldRoot->children;
			
			# If root has only one child, then it can simply be clipped from
			# the tree and its only child inhereits root.
			unless( 	defined $rootChildren[0] &&
						defined $rootChildren[1] ) 
			{
				$newRoot = defined $rootChildren[0] ? $rootChildren[0]
																: $rootChildren[1];
			}
			
			# One of the root's children will be the new root, only if its 
			# opposing child is empty... ie. root's left child's right child is 
			# empty, and vice-versa.
			# Hmmm... this elsif is redundant with the for, but I can't put a
			# for loop in the elsif condition!
			elsif( !(defined $rootChildren[0]->link(1) &&
					 	defined $rootChildren[1]->link(0)) ) 
			{
				for (0..1) {
					unless( defined $rootChildren[$_]->link(!$_) ) {
						$newRoot = $rootChildren[$_];
						$newRoot->link(!$_, $rootChildren[!$_]);
						last;
					}
				}
			}
			
			# Well... we have to find a suitable node and splay it up here.  So,
			# we grab the right subtree of the old root (or left, doesn't matter)
			# and splay up its smallest node (which is guarenteed not to have a
			# left child).  That then becomes the new root, and the old root's 
			# left child becomes the new root's left child.
			else {
				# Create a temporary tree to hold the old root's right subtree.
				# We splay to find its smallest member and drag it to the root.  
				# This root is guarenteed to have no left child, and thus we like 
				# it.
				my $tempTree = Tree::Smart->new;
				$tempTree->_root($oldRoot->right);
				$tempTree->_splay(undef);  # force a minimum splay, drag the smallest
													# node up.
				my $newRoot = $tempTree->_root;
				$newRoot->left($oldRoot->left);
			}
	
			$self->_root($newRoot);
			$self->{_numNodes}--;
	
			if( $self->{_minNode} == $oldRoot ) {
				$self->{_minNode} = $oldRoot->next;
			}
			elsif( $self->{_maxNode} == $oldRoot ) {
				$self->{_maxNode} = $oldRoot->prev;
			}
			# nothing else.
			
			$oldRoot->removeFromChain;
			
			return 1;
		}
	}
	else {
		return undef;
	}
}

# splaying for the smallest or greatest key is detremental to the
# balancing of the tree, so we weasel out of it.  Besides its easy to store
# the minimum and maximum nodes with splay trees, so why not?
sub _least {
	return $_[0]->{_minNode};
}	

sub _greatest {
	return $_[0]->{_maxNode};
}


#########################################################
# Where all the work is done.
package Tree::Smart::Node;

use vars qw(@ISA $VERSION);
BEGIN {
	@ISA = qw(Tree::Base::Node);
	$VERSION = 0.01;
}


# We perform a recursive top-down splay.  Everything depends on this routine.
# Any major performance improvements should probably be concentrated here.
sub _splay {
	my($self, $key, $storage) = @_;

	my($child, $grdchild);  # Our child and grandchild we move down to.
	my($dir1, $dir2);  	# The directions we traveled down the tree
								# to the child and grandchild, respectively.

	# Head down the path towards our key, chosing the appropriate child.
	$dir1 = $self->lt($key);
	$child = $self->link($dir1);
	
	# Terminating case #1.  We've found it, or we're out of tree.
	# Either way, return the current node.
	if( $self->eq($key) || !defined $child ) {
		return($self, $storage);    #-- RECURSION TERMINATION #1 --#
	}	

	# Now move down to our grandchild.
	$dir2 = $child->lt($key);
	$grdchild = $child->link($dir2);
		
	# Successful termination #2:  We've found our man, or we're out of tree,
	# same as #1, 'cept its our child.
	if( $child->eq($key) || !defined $grdchild ) {
		$self->link($dir1, undef);  # bust up the child and parent.
		$storage->hang(!$dir1, $self);  # place this node into storage.
		return($child, $storage);   #-- RECURSION TERMINATION #2 --#
	}
	
	# Rotate, gyrate, zig, zag, macarena... whatever.
	if( $dir1 == $dir2 ) {  # zig-zig, we're moving 'straight' down
		# parent takes the child's opposite child.
		$self->link( $dir1, $child->link(!$dir1) );
		# child replaces its oppositing child with its parent.
		$child->link( !$dir1, $self );
		# link between the child and the rest of the search path is broken
		$child->link( $dir1, undef );
		# Put this mess into storage.
		$storage->hang(!$dir1, $child);
	}
	else {  # zig-zag
		# bust up the parent and child... oh, ye homewrecker!
		$self->link($dir1, undef);
		# Store the parent and half the tree.
		$storage->hang(!$dir1, $self);
		# Bust up the child and grandchild... is there no mercy?
		$child->link($dir2, undef);
		# Store the child's half of the tree.
		$storage->hang(!$dir2, $child);
	}
	
	# And the recursion is handed down to the next generation.
	return $grdchild->_splay($key, $storage);
}


# We rig the comparison such that if an undefined key is looked for, it will
# always say the current key is greater.  This is jimmies the splaying to let
# us splay for the smallest node, necessary for deletion.
# This might not be necessary, 'cept I'm not sure what the result of a
# cmp between a string and undef is.
sub cmp {
	if( defined $_[1] ) {
		return ref $_[1] 	? $_[0]->key cmp $_[1]->key
								: $_[0]->key cmp $_[1];
	}
	else {
		return 1;
	}
}


##############################################################
# The special temporary storage tree used during splaying.
package Tree::Smart::Storage;

# This code isn't nearly as pretty as the rest of the module... sorry, I
# didn't put as much effort into it.

sub new {
	my($proto) = shift;
	my($class) = ref $proto || $proto;
	
	my $self = {
						leftRoot  => undef,	# The roots of the left and
						rightRoot => undef,	# right storage trees.	
						leftBottom 	=> undef,	# The bottom node of the left and
						rightBottom => undef		# right strorage trees.
					};
	
	bless($self, $class);
}


# Hang a subtree onto a storage tree.  Works like link.  First argument
# determines left or right subtree (0 or 1), second is a reference to the
# root of the subtree.  Thus $storage->hang(0, $tree) hangs the subtree $tree
# off of the left storage tree.  Also accepts 'left' and 'right'.
sub hang {
	my($self, $which, $subTree) = @_;
	
	if( $which eq 'left' ) 			{ $which = 0; }
	elsif ( $which eq 'right' ) 	{ $which = 1; }
	# nothing else
	
	if( defined $self->_root($which) ) {
		$self->_bottom($which, $subTree);
	}
	else {  # if there's no root, then its both the root and the bottom.
		$self->_root($which, $subTree);
		$self->_bottom($which, $subTree);
	}
	
	return 1;
}


# Public accessor to the left and right storage trees.
sub left {
	return $_[0]->_root(0);
}

sub right {
	return $_[0]->_root(1);
}


# Accessor to the bottom of each storage tree.
# When a new subtree is given this is hung off the old bottom node's
# opposite branch (thus on the left subtree, its hung off the old bottom's
# right branch) and the root of the subtree is made the new bottom.
#
# Incidentally, the opposing link of the new subtree is guarenteed to be
# null because of the nature of splaying.
sub _bottom {
	my( $self, $which, $subTree ) = @_;
	
	# Hang the subtree onto the our storage tree.
	if( @_ == 3 ) {
		if( $which == 0 ) {  # hang it on the left subtree.
			$self->{leftBottom}->link(!$which, $subTree) if defined $self->{leftBottom};
			$self->{leftBottom} = $subTree;
		}
		elsif( $which == 1 ) {  # hang it on the right.
			$self->{rightBottom}->link(!$which, $subTree) if defined $self->{rightBottom};
			$self->{rightBottom} = $subTree;
		}
		else {
			croak('Usage ', ref $self, '::_bottom($which, $subTree) where $which ',
					"is 0 or 1, not $which!");
		}
	}
	
	return $which ? $self->{leftBottom} : $self->{rightBottom};
}


# Accessor method for the roots of the left and right storage trees.
# Works similar to _bottom().
sub _root {
	my( $self, $which, $newRoot ) = @_;
	
	# Set a new root
	if( @_ == 3 ) {
		$which 	? $self->{leftRoot} 	= $newRoot
					: $self->{rightRoot}	= $newRoot;
	}
	
	return $which ? $self->{leftRoot} : $self->{rightRoot};
}


return 1;  # Cuz perl says so.

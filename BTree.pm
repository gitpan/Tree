# -*- mode: perl; perl-indent-level: 2 -*-
#
# Btree.pm
#
# B-Trees
#
# Copyright 1997 M-J. Dominus (mjd@pobox.com)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of any of:
#       1. Version 2 of the GNU General Public License as published by
#          the Free Software Foundation;
#       2. Any later version of the GNU public license, or
#       3. The Perl `Artistic License'
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the Artistic License with this
#    Kit, in the file named "Artistic".  If not, I'll be glad to provide one.
#
#    You should also have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#



package BTree::Node;
use Carp;

$KEYS = 0;
$DATA = 1;
$SUBNODES = 2;

# Each node has k key-data pairs, with B <= k <= 2B, and 
#     each has k+1 subnodes, which might be null.
# The node is a blessed reference to a list
# with three elements:
#  ($keylist, $datalist, $subnodelist)
# each is a reference to a list list.
# The null node is represented by a blessed reference to an empty list.

sub emptynode {
  new($_[0]);			# Pass package name, but not anything else.
}

# undef is empty; so is a blessed empty list.
sub is_empty {
  my $self = shift;
  !defined($self) || $#$self < 0;
}

sub key {
  my ($self, $n) = @_;
  $self->[$KEYS][$n];
}

sub data {
  my ($self, $n) = @_;
  $self->[$DATA][$n];
}

sub kdp {
  my ($self, $n, $k => $d) = @_;
  if (defined $k) {
    $self->[$KEYS][$n] = $k;
    $self->[$DATA][$n] = $d;
  }
  [$self->[$KEYS][$n], 
   $self->[$DATA][$n]];
}

sub subnode {
  my ($self, $n, $newnode) = @_;
  $self->[$SUBNODES][$n] = $newnode if defined $newnode;
  $self->[$SUBNODES][$n];
}

sub is_leaf {
  my $self = shift;
  ! defined $self->[$SUBNODES][0]; # undefined subnode means leaf node.
}

# Arguments: ($keylist, $datalist, $subnodelist)
# Special case: empty arg list to create empty node
sub new {
  my $self = shift;
  my $package = ref $self || $self;
  croak "Internal error:  BTree::Node::new called with wrong number of arguments."
      unless @_ == 3 || @_ == 0;
  bless [@_] => $package;
}

# Returns (1, $index) if $key[$index] eq $key.
# Returns (0, $index) if key could be found in $subnode[$index].
# In scalar context, just returns 1 or 0.
sub locate_key {
  # Use linear search for testing, replace with binary search.
  my $self = shift;
  my $key = shift;
  my $cmp = shift || \&BTree::default_cmp;
  my $i;
  my $cmp_result;
  my $N = $self->size;
  for ($i = 0; $i < $N; $i++) {
    $cmp_result = &$cmp($key, $self->key($i));
    last if $cmp_result <= 0;
  }
  
  # $i is now the index of the first node-key greater than $key
  # or $N if there is no such.  $cmp_result is 0 iff the key was found.
  (!$cmp_result, $i);
}

# Number of KEYS in the node
sub size {
  my $self = shift;
  return scalar(@{$self->[$KEYS]});
}

# No return value.
sub insert_kdp {
  my $self = shift;
  my ($k => $d) = @_;
  my ($there, $where) = $self->locate_key($k) unless $self->is_empty;

  if ($there) { croak("Tried to insert `$k => $d' into node where `$k' was already present."); }
  splice(@{$self->[$KEYS]}, $where, 0, $k);
  splice(@{$self->[$DATA]}, $where, 0, $d);
  splice(@{$self->[$SUBNODES]}, $where, 0, undef);
}

# Accept an index $n
# Divide into two nodes so that keys 0 .. $n-1 are in one node
# and keys $n+1 ... $size are in the other.
sub halves {
  my $self = shift;
  my $n = shift;
  my $s = $self->size;
  my @right;
  my @left;

  $left[$KEYS] = [@{$self->[$KEYS]}[0 .. $n-1]];
  $left[$DATA] = [@{$self->[$DATA]}[0 .. $n-1]];
  $left[$SUBNODES] = [@{$self->[$SUBNODES]}[0 .. $n]];

  $right[$KEYS] = [@{$self->[$KEYS]}[$n+1 .. $s-1]];
  $right[$DATA] = [@{$self->[$DATA]}[$n+1 .. $s-1]];
  $right[$SUBNODES] = [@{$self->[$SUBNODES]}[$n+1 .. $s]];

  my @middle = ($self->[$KEYS][$n], $self->[$DATA][$n]);

  ($self->new(@left), $self->new(@right), \@middle);
}

sub to_string {
  my $self = shift;
  my $indent = shift || 0;
  my $I = ' ' x $indent;
  return '' if $self->is_empty;
  my ($k, $d, $s) = @$self;
  my $result = '';
  $result .= defined($s->[0]) ? $s->[0]->to_string($indent+2) : '';
  my $N = $self->size;
  my $i;
  for ($i = 0; $i < $N; $i++) {
    $result .= $I . "$k->[$i] => $d->[$i]\n";
    $result .= defined($s->[$i+1]) ? $s->[$i+1]->to_string($indent+2) : '';
  }
  $result;
}



################################################################

package BTree;

use Exporter;
@ISA = (Exporter);

BEGIN { import BTree::Node };

use Carp;


# Semantics:
#  If key not found, insert it iff `Insert' arg is present
#  If key *is* found, replace existing data iff `Replace' arg is present.

sub B_search {
  my $self = shift;
  my %args = @_;
  my $cur_node = $self->root;
  my $k = $args{Key};
  my $d = $args{Data};
  my @path;

  if ($cur_node->is_empty) {	# Special case for empty root
    if ($args{Insert}) {
      $cur_node->insert_kdp($k => $d);
      return $d;
    } else {
      return undef;
    }
  }

  # Descend tree to leaf
  for (;;) {

    # Didn't hit bottom yet.

    my($there, $where) = $cur_node->locate_key($k);
    if ($there) {		# Found it!
      if ($args{Replace}) {
	$cur_node->kdp($where, $k => $d);
      } 
      return $cur_node->data($where);
    }
    
    # Not here---must be in a subtree.
    
    if ($cur_node->is_leaf) {	# But there are no subtrees
      return undef unless $args{Insert}; # Search failed
      # Stuff it in
      $cur_node->insert_kdp($k => $d);
      if ($self->node_overfull($cur_node)) { # Oops--there was no room.
	$self->split_and_promote($cur_node, @path);
      } 
      return $d;
    }

    # There are subtrees, and the key is in one of them.

    push @path, [$cur_node, $where];	# Record path from root.

    # Move down to search the subtree
    $cur_node = $cur_node->subnode($where);

    # and start over.
  }				# for (;;) ...

  croak ("How did I get here?");
}



sub split_and_promote_old {
  my $self = shift;
  my ($cur_node, @path) = @_;
  
  for (;;) {
    my ($newleft, $newright, $kdp) = $cur_node->halves($self->B / 2);
    my ($up, $where) = @{pop @path};
    if ($up) {
      $up->insert_kdp(@$kdp);
      my ($tthere, $twhere) = $up->locate_key($kdp->[0]);
      croak "Couldn't find key `$kdp->[0]' in node after just inserting it!"
	  unless $tthere;
      croak "`$kdp->[0]' went into node at `$twhere' instead of expected `$where'!"
	  unless $twhere == $where;
      $up->subnode($where,   $newleft);
      $up->subnode($where+1, $newright);
      return unless $self->node_overfull($up);
      $cur_node = $up;
    } else { # We're at the top; make a new root.
      my $newroot = new BTree::Node ([$kdp->[0]], 
				     [$kdp->[1]], 
				     [$newleft, $newright]);
      $self->root($newroot);
      return;
    }
  }
  
}

sub split_and_promote {
  my $self = shift;
  my ($cur_node, @path) = @_;
  
  for (;;) {
    my ($newleft, $newright, $kdp) = $cur_node->halves($self->B / 2);
    my ($up, $where) = @{pop @path};
    if ($up) {
      $up->insert_kdp(@$kdp);
      if ($DEBUG) {
        my ($tthere, $twhere) = $up->locate_key($kdp->[0]);
        croak "Couldn't find key `$kdp->[0]' in node after just inserting it!"
  	  unless $tthere;
        croak "`$kdp->[0]' went into node at `$twhere' instead of expected `$where'!"
	  unless $twhere == $where;
      }
      $up->subnode($where,   $newleft);
      $up->subnode($where+1, $newright);
      return unless $self->node_overfull($up);
      $cur_node = $up;
    } else { # We're at the top; make a new root.
      my $newroot = new BTree::Node ([$kdp->[0]], 
				     [$kdp->[1]], 
				     [$newleft, $newright]);
      $self->root($newroot);
      return;
    }
  }
}

sub B {
  $_[0]{B};
}

sub root {
  my ($self, $newroot) = @_;
  $self->{Root} = $newroot if defined $newroot;
  $self->{Root};
}

sub node_overfull {
  my $self = shift;
  my $node = shift;
  $node->size > $self->B;
}


# Data structure:
# A B-Tree has a constant, B.  It has a root node, which may have child nodes.
# The node is an object from BTree::Node;

sub new {
  my $package = shift;
  my %ARGV = @_;
  croak "Usage: {$package}::new(B => number [, Root => root node ])"
      unless exists $ARGV{B};
  if ($ARGV{B} % 2) {
    my $B = $ARGV{B} + 1;
    carp "B must be an even number.  Using $B instead.";
    $ARGV{B} = $B;
  }
    
  my $B = $ARGV{B};
  my $Root = exists($ARGV{Root}) ? $ARGV{Root} : BTree::Node->emptynode;
  bless { B => $B, Root => $Root } => $package;
}

sub to_string {
  $_[0]->root->to_string;
}

sub default_cmp {
  $_[0] cmp $_[1];
}

#!/usr/bin/perl
# -*- mode: perl; perl-indent-level: 2 -*-

use BTree;

@letter = ('a' .. 'z');

# $SHUFFLE = 1;  # Use this to permute the letters at random
# $REVERSE = 1;  # Or use this to reverse the list of letters

if ($SHUFFLE) {
  my @r;
  while (@letter) {
    push @r, splice(@letter, int(rand @letter), 1);
  }
  @letter = @r;
} elsif ($REVERSE) {
  @letter = reverse @letter;
}

# The `2' here is the B constant.
# Change it to 4 or 6 for different results.

$tree = new BTree B => 2;

for ($number = 0; $number < @letter; $number++) {
  print qq{

--------------------------------
$number
};
  $tree->B_search(Key => $letter[$number], 
		  Data => $number, 
		  Insert => 1,
		  );
  print $tree->to_string;
}


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}

use Tree::Smart;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$testNum = 1;

# Perform our checks on null cases.
$testNum++;
unless( defined( $tree = Tree::Smart->new ) ) {
	print "not ";
}
print "ok new() $testNum\n";



# Try dealing with a simple tree.
$testNum++;

# Initialize some dummy data.
%dummyHash = (
					this		=> 	that,
					foo		=>		bar,
					up			=>		down,
					day		=>		night,
					left		=>		right,
					in			=>		out,
					over		=>		under,
					black		=>		white
				 );

$tree->insert(%dummyHash);
print "ok insert() $testNum\n";


$testNum++;
# try a delete.
$tree->insert('delete', 'this');  $tree->insert('bye', 'bye');
# shuffle things around a bit.
$tree->find('up');  $tree->find('foo');  $tree->find('black');
$tree->delete('delete');  $tree->delete('bye');
if( 	$tree->exists('delete') ||
		$tree->exists('bye') )
{
	print "not ";
}

print "ok delete() $testNum\n";


$testNum++;

@treeKeys 		= $tree->keys;
@treeValues 	= $tree->values;

@sortedDummyKeys = sort {$a cmp $b} keys %dummyHash;

# check to see if the tree's idea of stored data checks out.
foreach (0..@sortedDummyKeys) {
	unless( 	$sortedDummyKeys[$_] 	eq $treeKeys[$_] &&
				$dummyHash{$sortedDummyKeys[$_]} eq $treeValues[$_] )
	{
		print "not ";
		last;
	}
}

print "ok basic keys() & values() $testNum\n";

$testNum++;
# Test keys()' full functionality.
KEYSTEST: { 
	@partialKeys = $tree->keys($sortedDummyKeys[4]);
	unless( 	$partialKeys[0] eq  $sortedDummyKeys[4] && 
				$partialKeys[-1] eq $sortedDummyKeys[-1] ) {
		print "not ";
		last KEYSTEST;
	}
	
	@partialKeys = $tree->keys(undef, $sortedDummyKeys[-3]);
	unless( 	$partialKeys[-1] eq $sortedDummyKeys[-3] && 
				$partialKeys[0] eq @sortedDummyKeys[0] ) {
		print "not ";
		last KEYSTEST;
	}
	
	@partialKeys = $tree->keys('dah', 'ruff');
	unless( 	$partialKeys[0] 	eq 'day' &&
				$partialKeys[-1] 	eq 'over' ) {
		print "not ";
		last KEYSTEST;
	}
}

print "ok full keys() test $testNum\n";

$testNum++;
# Test next() and prev().
NEXTTEST: {
	unless( $tree->next('f') eq 'foo' ) { print "not ";  last NEXTTEST; }
	unless( $tree->next eq 'in' ) { print "not ";  last NEXTTEST; }
	unless( $tree->prev eq 'foo' ) { print "not ";  last NEXTTEST; }
	unless( !defined $tree->prev('a') ) { print "not ";  last NEXTTEST; }

	$tree->reset;  
	@keys = (scalar $tree->next, scalar $tree->next, 
				scalar $tree->next, scalar $tree->prev, 
				scalar$tree->prev);
	for (0..int @keys/2) { 
		unless( 	$keys[$_] eq $keys[-($_ + 1)] &&
					$keys[$_] eq $sortedDummyKeys[$_] ) 
		{
			print "not ";  last NEXTTEST;
		}
	}
}			

print "ok next() and prev() $testNum\n";

	
# Check least() & greatest()
$testNum++;
unless( ($tree->least)[0] eq $sortedDummyKeys[0] ) { print "not "; }
print "ok least() $testNum\n";

$testNum++;
unless( ($tree->greatest)[0] eq $sortedDummyKeys[-1] ) { print "not "; }
print "ok greatest() $testNum\n";


# Try some finds.
$testNum++;

foreach (keys %dummyHash) { 
	unless( $tree->find($_) eq $dummyHash{$_} ) {
		print "not ";
		last;
	}
}

print "ok basic find() $testNum\n";


# Try exists()
$testNum++;

foreach (keys %dummyHash) { 
	unless( $tree->exists($_) ) {
		print "not ";
		last;
	}
}

print "ok basic exists() $testNum\n";




# Try some basic tying.
TIE: {
	tie(%treeHash, 'Tree::Smart', %dummyHash);

	@treeHashKeys = keys %treeHash;
	foreach (0..$#treeHashKeys) {
		unless( $treeHashKeys[$_] eq $sortedDummyKeys[$_] ) {
			print "not ";
			last TIE;
		}
	}
	
	unless( $treeHash{'foo'} eq 'bar' ) {
		print "not "; 
		last TIE;
	}
	
	$treeHash{'up'} = 'slideways';
	unless( $treeHash{'up'} eq 'slideways' ) {
		print "not ";
		last TIE;
	}
	
	delete $treeHash{'black'};
	if( exists $treeHash{'black'} ) {
		print "not ";
		last TIE;
	}
	
	@hashKeys 	= keys %treeHash;
	@hashValues = values %treeHash;
	while( ($key, $value) = each %treeHash ) {
		unless( 	$key eq shift @hashKeys &&
					$value eq shift @hashValues )
		{
			print "not ";
			last TIE;
		}
	}
	
	%treeHash = ();
	untie %treeHash;
}

print "ok tie interface $testNum\n";

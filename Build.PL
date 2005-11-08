use Module::Build;

use 5.6.0;

use strict;
use warnings;

eval "use Tree::Binary;";
unless ($@) {
    if ( (my $version = Tree::Binary->VERSION) <= 0.07 ) {
        my $tree_binary_msg = "You currently have Tree::Binary version $version installed.\nThis distribution will install an incompatible Tree::Binary module on top of it.\nDo you wish for me to continue?";

        if ( !Module::Build->y_n( $tree_binary_msg, 'n' ) ) {
            exit;
        }
    }
}

my $build = Module::Build->new(
    module_name => 'Tree',
    license => 'perl',
    requires => {
        'perl'               => '5.6.0',
        'Scalar::Util'       => '1.10',
    },
    build_requires => {
        'Scalar::Util'         => '1.10',
        'Test::Deep'           => '0.088',
        'Test::Exception'      => '0.15',
        'Test::More'           => '0.47',
        'Test::Warn'           => '0.08',
    },
    create_makefile_pl => 'traditional',
    recursive_test_files => 1,
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', 'Makefile.PL',
    ],
);

$build->create_build_script;

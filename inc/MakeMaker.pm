package inc::MakeMaker;

use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';
Dist::Zilla::Plugin::MakeMaker::Awesome->VERSION("0.35");

override _build_MakeFile_PL_template => sub {
    my $self = shift;

    my $tmpl = super();

    # strip "generated by" boilerplate
    $tmpl =~ s/\A.*?^use strict;/use strict;/ms;

    my $assert_compiler = << 'HERE';
use lib 'inc';
use BSONConfig;

BSONConfig::check_for_compiler();

HERE

    # splice in our stuff after the preamble bits
    # TODO - MMA ought to make this easier.
    $tmpl =~ m/use warnings;\n\n/g;
    $tmpl =
      substr( $tmpl, 0, pos($tmpl) ) . $assert_compiler . substr( $tmpl, pos($tmpl) );

    # add our custom config
    my $mutator = "BSONConfig::configure(\\%WriteMakefileArgs);\n\n";

    unless ( $tmpl =~ s{^(WriteMakefile\(%WriteMakefileArgs\))}{$mutator$1}ms ) {
        die "Can't fix Makefile.PL:\n $tmpl\n";
    }
    return $tmpl;
};

override _build_WriteMakefile_args => sub {
    my $self = shift;

    my $args = super();

    return { %{$args}, _mm_args(), };
};

override test => sub {
    my $self = shift;

    local $ENV{PERL5LIB} = join ':',
      grep { defined } @ENV{ 'PERL5LIB', 'DZIL_TEST_INC' };

    super();
};

sub _mm_args {
    my ( @object, %xs );

    for my $xs ( glob "xs/*.xs" ) {
        ( my $c = $xs ) =~ s/\.xs$/.c/i;
        ( my $o = $xs ) =~ s/\.xs$/\$(OBJ_EXT)/i;

        $xs{$xs} = $c;
        push @object, $o;
    }

    for my $c ( glob("*.c"), glob("bson/*.c") ) {
        ( my $o = $c ) =~ s/\.c$/\$(OBJ_EXT)/i;
        push @object, $o;
    }

    return (
        clean => { FILES => join( q{ }, @object ) },
        OBJECT => join( q{ }, @object ),
        XS     => \%xs,
    );
}

sub _MY_package_subs {
    my $str = do { local ( @ARGV, $/ ) = "inc/MM_pkg_MY.pl"; <> };
    $str =~ s{^use strict;\n^use warnings;\n}{}m;
    return $str;
}

1;

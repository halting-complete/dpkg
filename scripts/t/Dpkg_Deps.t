#!/usr/bin/perl
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use strict;
use warnings;

use Test::More tests => 45;

use Dpkg::Arch qw(get_host_arch);
use Dpkg::Version;

use_ok('Dpkg::Deps');

is(deps_concat(), '', 'Concatenate an empty list');
is(deps_concat(undef), '', 'Concatenate list with undef');
is(deps_concat(''), '', 'Concatenate an empty string');
is(deps_concat('', undef), '', 'Concatenate empty string with undef');
is(deps_concat('dep-a', undef, 'dep-b'), 'dep-a, dep-b',
   'Concatenate two strings with intermixed undef');

my $field_multiline = ' , , libgtk2.0-common (= 2.10.13-1)  , libatk1.0-0 (>=
1.13.2), libc6 (>= 2.5-5), libcairo2 (>= 1.4.0), libcupsys2 (>= 1.2.7),
libfontconfig1 (>= 2.4.0), libglib2.0-0  (  >= 2.12.9), libgnutls13 (>=
1.6.3-0), libjpeg62, python (<< 2.5) , , ';
my $field_multiline_sorted = 'libatk1.0-0 (>= 1.13.2), libc6 (>= 2.5-5), libcairo2 (>= 1.4.0), libcupsys2 (>= 1.2.7), libfontconfig1 (>= 2.4.0), libglib2.0-0 (>= 2.12.9), libgnutls13 (>= 1.6.3-0), libgtk2.0-common (= 2.10.13-1), libjpeg62, python (<< 2.5)';

my $dep_multiline = deps_parse($field_multiline);
$dep_multiline->sort();
is($dep_multiline->output(), $field_multiline_sorted, 'Parse, sort and output');

my $dep_sorted = deps_parse('pkgz, pkgz | pkga, pkga (>= 1.0), pkgz (<= 2.0)');
$dep_sorted->sort();
is($dep_sorted->output(), 'pkga (>= 1.0), pkgz, pkgz | pkga, pkgz (<= 2.0)', 'Check sort() algorithm');

my $dep_subset = deps_parse('libatk1.0-0 (>> 1.10), libc6, libcairo2');
is($dep_multiline->implies($dep_subset), 1, 'Dep implies subset of itself');
is($dep_subset->implies($dep_multiline), undef, "Subset doesn't imply superset");
my $dep_opposite = deps_parse('python (>= 2.5)');
is($dep_opposite->implies($dep_multiline), 0, 'Opposite condition implies NOT the depends');

my $dep_or1 = deps_parse('a|b (>=1.0)|c (>= 2.0)');
my $dep_or2 = deps_parse('x|y|a|b|c (<= 0.5)|c (>=1.5)|d|e');
is($dep_or1->implies($dep_or2), 1, 'Implication between OR 1/2');
is($dep_or2->implies($dep_or1), undef, 'Implication between OR 2/2');

my $dep_ma_any = deps_parse('libcairo2:any');
my $dep_ma_native = deps_parse('libcairo2');
my $dep_ma_native2 = deps_parse('libcairo2:native', build_dep => 1);
is($dep_ma_native->implies($dep_ma_any), 1, 'foo -> foo:any');
is($dep_ma_native2->implies($dep_ma_any), 1, 'foo:native -> foo:any');
is($dep_ma_any->implies($dep_ma_native), undef, 'foo:any !-> foo');
is($dep_ma_any->implies($dep_ma_native2), undef, 'foo:any !-> foo:native');

my $field_arch = 'libc6 (>= 2.5) [!alpha !hurd-i386], libc6.1 [alpha], libc0.1 [hurd-i386]';
my $dep_i386 = deps_parse($field_arch, reduce_arch => 1, host_arch => 'i386');
my $dep_alpha = deps_parse($field_arch, reduce_arch => 1, host_arch => 'alpha');
my $dep_hurd = deps_parse($field_arch, reduce_arch => 1, host_arch => 'hurd-i386');
is($dep_i386->output(), 'libc6 (>= 2.5)', 'Arch reduce 1/3');
is($dep_alpha->output(), 'libc6.1', 'Arch reduce 2/3');
is($dep_hurd->output(), 'libc0.1', 'Arch reduce 3/3');

my $field_profile = 'dep1 <!stage1 !nocheck>, ' .
'dep2 <stage1 !nocheck>, ' .
'dep3 <nocheck !stage1>, ' .
'dep4 <stage1 nocheck>, ' .
'dep5 <stage1>, dep6 <!stage1>, ' .
'dep7 <stage1> | dep8 <nocheck>, ' .
'dep9 <!stage1> <!nocheck>, ' .
'dep10 <stage1> <!nocheck>, ' .
'dep11 <stage1> <nocheck>, '.
'dep12 <!nocheck> <!stage1>, ' .
'dep13 <nocheck> <!stage1>, ' .
'dep14 <nocheck> <stage1>';
my $dep_noprof = deps_parse($field_profile, reduce_profiles => 1, build_profiles => []);
my $dep_stage1 = deps_parse($field_profile, reduce_profiles => 1, build_profiles => ['stage1']);
my $dep_nocheck = deps_parse($field_profile, reduce_profiles => 1, build_profiles => ['nocheck']);
my $dep_stage1nocheck = deps_parse($field_profile, reduce_profiles => 1, build_profiles => ['stage1', 'nocheck']);
is($dep_noprof->output(), 'dep1, dep6, dep9, dep10, dep12, dep13', 'Profile reduce 1/4');
is($dep_stage1->output(), 'dep2, dep5, dep7, dep9, dep10, dep11, dep12, dep14', 'Profile reduce 2/4');
is($dep_nocheck->output(), 'dep3, dep6, dep8, dep9, dep11, dep12, dep13, dep14', 'Profile reduce 3/4');
is($dep_stage1nocheck->output(), 'dep4, dep5, dep7 | dep8, dep10, dep11, dep13, dep14', 'Profile reduce 4/4');

$dep_noprof = deps_parse($field_profile);
$dep_noprof->reduce_profiles([]);
$dep_stage1 = deps_parse($field_profile);
$dep_stage1->reduce_profiles(['stage1']);
$dep_nocheck = deps_parse($field_profile);
$dep_nocheck->reduce_profiles(['nocheck']);
$dep_stage1nocheck = deps_parse($field_profile);
$dep_stage1nocheck->reduce_profiles(['stage1', 'nocheck']);
is($dep_noprof->output(), 'dep1, dep6, dep9, dep10, dep12, dep13', 'Profile post-reduce 1/4');
is($dep_stage1->output(), 'dep2, dep5, dep7, dep9, dep10, dep11, dep12, dep14', 'Profile post-reduce 2/4');
is($dep_nocheck->output(), 'dep3, dep6, dep8, dep9, dep11, dep12, dep13, dep14', 'Profile post-reduce 3/4');
is($dep_stage1nocheck->output(), 'dep4, dep5, dep7 | dep8, dep10, dep11, dep13, dep14', 'Profile post-reduce 4/4');

my $field_restrict = 'dep1 <!bootstrap !restrict>, ' .
'dep2 <bootstrap restrict>, ' .
'dep3 <!restrict>, ' .
'dep4 <restrict>, ' .
'dep5 <!bootstrap> <!restrict>, ' .
'dep6 <bootstrap> <restrict>';
my $dep_restrict = deps_parse($field_restrict, reduce_restrictions => 1, build_profiles => []);
is($dep_restrict->output(), 'dep1, dep3, dep5', 'Unknown restrictions reduce');

$dep_restrict = deps_parse($field_restrict);
$dep_restrict->reduce_profiles([]);
is($dep_restrict->output(), 'dep1, dep3, dep5', 'Unknown restrictions post-reduce');

my $facts = Dpkg::Deps::KnownFacts->new();
$facts->add_installed_package('mypackage', '1.3.4-1', get_host_arch(), 'no');
$facts->add_installed_package('mypackage2', '1.3.4-1', 'somearch', 'no');
$facts->add_installed_package('pkg-ma-foreign', '1.3.4-1', 'somearch', 'foreign');
$facts->add_installed_package('pkg-ma-foreign2', '1.3.4-1', get_host_arch(), 'foreign');
$facts->add_installed_package('pkg-ma-allowed', '1.3.4-1', 'somearch', 'allowed');
$facts->add_installed_package('pkg-ma-allowed2', '1.3.4-1', 'somearch', 'allowed');
$facts->add_installed_package('pkg-ma-allowed3', '1.3.4-1', get_host_arch(), 'allowed');
$facts->add_provided_package('myvirtual', undef, undef, 'mypackage');
$facts->add_provided_package('myvirtual2', REL_EQ, '1.0-1', 'mypackage');
$facts->add_provided_package('myvirtual3', REL_GE, '2.0-1', 'mypackage');

my $field_duplicate = 'libc6 (>= 2.3), libc6 (>= 2.6-1), mypackage (>=
1.3), myvirtual | something, python (>= 2.5), mypackage2, pkg-ma-foreign,
pkg-ma-foreign2, pkg-ma-allowed:any, pkg-ma-allowed2, pkg-ma-allowed3';
my $dep_dup = deps_parse($field_duplicate);
$dep_dup->simplify_deps($facts, $dep_opposite);
is($dep_dup->output(), 'libc6 (>= 2.6-1), mypackage2, pkg-ma-allowed2', 'Simplify deps');

my $field_virtual = 'myvirtual | other';
my $dep_virtual = deps_parse($field_virtual);
$dep_virtual->simplify_deps($facts);
is($dep_virtual->output(), '',
   'Simplify unversioned depends with unversioned virtual (satisfied)');

$field_virtual = 'myvirtual (>= 1.0) | other';
$dep_virtual = deps_parse($field_virtual);
$dep_virtual->simplify_deps($facts);
is($dep_virtual->output(), 'myvirtual (>= 1.0) | other',
   'Simplify versioned depends on unversioned virtual (unsatisfied)');

$field_virtual = 'myvirtual2 (>= 0.0) | other';
$dep_virtual = deps_parse($field_virtual);
$dep_virtual->simplify_deps($facts);
is($dep_virtual->output(), '',
   'Simplify versioned depends on versioned virtual (satisfied)');

$field_virtual = 'myvirtual2 (>= 2.0) | other';
$dep_virtual = deps_parse($field_virtual);
$dep_virtual->simplify_deps($facts);
is($dep_virtual->output(), 'myvirtual2 (>= 2.0) | other',
   'Simplify versioned depends on versioned virtual (unsatisfied)');

$field_virtual = 'myvirtual3 (= 2.0-1)';
$dep_virtual = deps_parse($field_virtual);
$dep_virtual->simplify_deps($facts);
is($dep_virtual->output(), 'myvirtual3 (= 2.0-1)',
   'Simplify versioned depends on GT versioned virtual (unsatisfied/ignored)');

my $field_dup_union = 'libc6 (>> 2.3), libc6 (>= 2.6-1), fake (<< 2.0),
fake(>> 3.0), fake (= 2.5), python (<< 2.5), python (= 2.4)';
my $dep_dup_union = deps_parse($field_dup_union, union => 1);
$dep_dup_union->simplify_deps($facts);
is($dep_dup_union->output(), 'libc6 (>> 2.3), fake (<< 2.0), fake (>> 3.0), fake (= 2.5), python (<< 2.5)', 'Simplify union deps');

$dep_dup_union = deps_parse('sipsak (<= 0.9.6-2.1), sipsak (<= 0.9.6-2.2)', union => 1);
$dep_dup_union->simplify_deps($facts);
is($dep_dup_union->output(), 'sipsak (<= 0.9.6-2.2)', 'Simplify union deps 2');

my $dep_red = deps_parse('abc | xyz, two, abc');
$dep_red->simplify_deps($facts, $dep_opposite);
is($dep_red->output(), 'abc, two', 'Simplification respect order');
is("$dep_red", $dep_red->output(), 'Stringification == output()');

my $dep_empty1 = deps_parse('');
is($dep_empty1->output(), '', 'Empty dependency');

my $dep_empty2 = deps_parse(' , , ', union => 1);
is($dep_empty2->output(), '', "' , , ' is also an empty dependency");

$SIG{__WARN__} = sub {};
my $dep_bad_multiline = deps_parse("a, foo\nbar, c");
ok(!defined($dep_bad_multiline), 'invalid dependency split over multiple line');
delete $SIG{__WARN__};

my $dep_iter = deps_parse('a, b:armel, c | d:armhf, d:mips (>> 1.2)');
my %dep_arches;
my %dep_pkgs;
deps_iterate($dep_iter, sub {
    my $dep = shift;

    $dep_pkgs{$dep->{package}} = 1;
    if ($dep->{archqual}) {
        $dep_arches{$dep->{archqual}} = 1;
    }
    return 1;
});
my @dep_arches = sort keys %dep_arches;
my @dep_pkgs = sort keys %dep_pkgs;
is("@dep_arches", 'armel armhf mips', 'Dependency iterator, get arches');
is("@dep_pkgs", 'a b c d', 'Dependency iterator, get packages');

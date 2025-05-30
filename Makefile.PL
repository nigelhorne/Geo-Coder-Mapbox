use strict;
use warnings;
use ExtUtils::MakeMaker 6.64;	# 6.64 for TEST_REQUIRES
use Getopt::Long;	# Technique inspired by IO::Lambda
use IO::Socket::INET;

my $online_tests;

# Test for broken smokers that don't set AUTOMATED_TESTING
if(my $reporter = $ENV{'PERL_CPAN_REPORTER_CONFIG'}) {
	if($reporter =~ /smoker/i) {
		warn 'AUTOMATED_TESTING added for you';
		$ENV{'AUTOMATED_TESTING'} = 1;
	}
}

if($ENV{AUTHOR_TESTING}) {
	$online_tests = are_online();
} else {
	Getopt::Long::GetOptions('online-tests!' => \$online_tests);

	if(!defined($online_tests)) {
		$online_tests = are_online();
	}
	if(!$online_tests) {
		print "On-line tests have been disabled\n";
		$online_tests = 0;
	}
}

my $test_requires = {
	'Test::Compile' => 0,
	'Test::DescribeMe' => 0,
	'Test::Most' => 0,
	'Test::Needs' => 0,
	'Test::NoWarnings' => 0,
	'Test::Number::Delta' => 0,
	'Test::RequiresInternet' => 0,
	'Test::Requires' => 0,
};

if($online_tests) {
	open(my $enabled, '>', 't/online.enabled') || die "Can't touch t/online.enabled $!";
	close($enabled) || die "Can't touch t/online.enabled $!";
	$test_requires->{'Test::LWP::UserAgent'} = 0;
	$test_requires->{'Test::Number::Delta'} = 0;
	$test_requires->{'Test::Carp'} = 0;
} else {
	unlink('t/online.enabled');
}

WriteMakefile(
    NAME		=> 'Geo::Coder::Mapbox',
    AUTHOR		=> q{Nigel Horne <njh@bandsman.co.uk>},
    VERSION_FROM	=> 'lib/Geo/Coder/Mapbox.pm',
    ABSTRACT_FROM       => 'lib/Geo/Coder/Mapbox.pm',
    ((defined($ExtUtils::MakeMaker::VERSION) &&
     ($ExtUtils::MakeMaker::VERSION >= 6.3002))
      ? ('LICENSE'=> 'GPL')
      : ()),
    PL_FILES	=> {},
	TEST_REQUIRES => $test_requires,
    PREREQ_PM => {
	'Encode' => 0,
	'JSON::MaybeXS' => 0,
	'HTTP::Request' => 0,
	'LWP::UserAgent' => 0,
	'LWP::Protocol::https' => 0,
	'URI' => 0,
    },
    dist		=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean		=> { FILES => 'Geo-Coder-Mapbox-*' },
    META_MERGE		=> {
    	'meta-spec' => { version => 2 },
    	resources => {
    		repository => {
			type => 'git',
			url => 'git://github.com/nigelhorne/Geo-Coder-Mapbox.git',
			web => 'https://github.com/nigelhorne/Geo-Coder-Mapbox',
    		},
		bugtracker => {
			web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Geo-Coder-Mapbox',
			mailto => 'bug-Geo-Coder-Mapbox@rt.cpan.org'
		}
	},
    },
    MIN_PERL_VERSION	=> '5.6.2'	# Probably would work, but never tested on earlier versions than this
);

sub are_online
{
	return 0 if($ENV{'NO_NETWORK_TESTING'} || $ENV{'CIRCLECI'} || $ENV{'TRAVIS_PERL_VERSION'} || $ENV{'AUTOMATED_TESTING'} || $ENV{'NONINTERACTIVE_TESTING'} || (!-t STDIN));

	if(my $s = IO::Socket::INET->new(
		PeerAddr => 'mapbox.com:443',
		Timeout => 10
	)) {
		if($ENV{'PERL_MM_USE_DEFAULT'}) {
			close($s);
			return 1;
		}
		print <<EOF;

You appear to be directly connected to the Internet.  I have some tests
that try to query mapbox.com.

EOF
		close($s);

		# Timeout inspired by Mail::IMAPClient
		my $rc;
		eval {
			local $SIG{ALRM} = sub { die 'alarm' };
			alarm(60);
			$rc = prompt('Do you want to enable these tests?', 'y') =~ /^y/i ? 1 : 0;
			alarm(0);
		};
		if($@) {
			print "\n";
			return 1;	# The default is 'y'
		}
		return $rc;
	}
	print "On-line tests disabled because I couldn't detect an Internet connexion\n";
	return 0;
}

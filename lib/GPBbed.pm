#!/usr/bin/perl

package GPBbed;

use strict;
use warnings;


sub load_bed {
	my ($bed_file, $region) = @_;
	open my $fh_bed, '<', $bed_file or die "Error: Can't open file '$bed_file': $!\n";

	my ($reg_chr, $reg_start, $reg_end) = @{$region}[1..3];

	my @se;
	my $line_no = 0;
	while (my $line = <$fh_bed>) {
		$line_no++;
		next if $line =~ /^#/;
		next if $line =~ /^\s*$/;
		$line =~ s/\s+$//;
		my @f = split /\t/, $line;

		@f == 4 or die "Line $line_no: expected 4 columns:sequence,start,end,annotation; got " . scalar(@f) . "\n";

		$f[1] =~ /^[0-9]+$/ or die "Error: Line $line_no in file '$bed_file': start '$f[1]' not integer\n";
		$f[2] =~ /^[0-9]+$/ or die "Error: Line $line_no in file '$bed_file': end   '$f[2]' not integer\n";
		$f[1] < $f[2]       or die "Error: Line $line_no in file '$bed_file': start >= end\n";

		next unless $f[0] eq $reg_chr;
		next unless $f[2] > $reg_start && $f[1] < $reg_end;

		$f[1]++;
		push @se, [$f[1], $f[2], $f[3]];
	}

	close  $fh_bed;

	@se = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @se;

	return \@se;
}



1;

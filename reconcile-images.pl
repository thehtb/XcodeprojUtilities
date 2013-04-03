#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(basename);

my @image_files = `find . -name '*.png' -or -name '*.jpg'`;
chomp @image_files;
@image_files = map { basename $_ } @image_files;
my %file_image_names = map { strip_ext($_) => 1 } @image_files;

my @image_named_uses = `find . -name '*.m' -print0 | xargs -0 grep 'imageNamed:'`;
my @xib_resources = `find . -name '*.xib' -print0 | xargs -0 grep 'NSResourceName'`;

my %images_used;
my %missing_2x;
my %missing_1x;

for my $xib_resource_name (@xib_resources)
{
    if ($xib_resource_name =~ m!<string key="NSResourceName">([^>]+)</string>!)
    {
        $images_used{strip_ext($1)} = 1;
    }
}

for my $image_named_message (@image_named_uses)
{
    my @image_names;
    
    if ( $image_named_message =~ /imageNamed: *\@"([^"]+)"/ )
    {
        push @image_names, $1;
    }
    elsif ( $image_named_message =~ /(.*)\.m:.*imageNamed: *([a-zA-Z0-9_\.]+ *)\]/ )
    {
        # find the variable/property assignment
        my $source_filename = "$1.m";
        my $variable_name = $2;

        open my $fh, $source_filename
            or die $!;
                
        push @image_names, $_
            for grep { $_ } map { /$variable_name *= *\@"([^"]+)"/ && $1 } <$fh>;
        
    }
    elsif ( $image_named_message =~ /imageNamed:.*\? *\@"([^"]+)" *: *\@"([^"]+)"/)
    {
        # found a ternary operator with two image strings
        push @image_names, $1, $2;
    }
    else
    {
        warn "suspicious line: $image_named_message";
        next;
    }

    $images_used{$_} = 1
        for map { strip_ext($_) } @image_names;
}

for my $image (keys %images_used)
{
    $images_used{$image} = 1;

    $missing_1x{$image} = 1
        if ! exists $file_image_names{$image};

    $missing_2x{$image} = 1
        if ! exists $file_image_names{"$image\@2x"};
}

my %unreferenced_files;

for my $filename (@image_files)
{
    my $image_name = strip_2x(strip_ext($filename));

    $unreferenced_files{$filename} = 1
        if ! exists $images_used{$image_name};
}

my $missing_2x_count = scalar(keys %missing_2x);
my $missing_1x_count = scalar(keys %missing_1x);
my $unreferenced_file_count = scalar(keys %unreferenced_files);

my $warnings = 0;
if ($missing_2x_count)
{
    print "You're missing the following $missing_2x_count \@2x files:\n";
    print "  $_\@2x\n"
        for sort keys %missing_2x;
    print "\n";

    $warnings++;
}

if ($missing_1x_count)
{
    print "You're missing the following $missing_1x_count \@1x files:\n";
    print "  $_\n"
        for sort keys %missing_1x;
    print "\n";

    $warnings++;
}

if ($unreferenced_file_count)
{
    print "Can't see any imageNamed: call for the following $unreferenced_file_count files:\n";
    print "  $_\n"
        for sort keys %unreferenced_files;
    print "\n";

    $warnings++;
}

if (!$warnings)
{
    print "No problems found.\n";
}

sub strip_ext {
    my $filename = shift;

    $filename =~ s/\.png$//;
    $filename =~ s/\.jpg$//;

    return $filename;
}

sub strip_2x {
    my $image_name = shift;

    $image_name =~ s/\@2x$//;

    return $image_name;
}

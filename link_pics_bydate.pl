#!/usr/bin/perl -w

# read a list of filenames on stdin and store in the local directory

# usage: link_pics_bydate.pl <dir1> <dir2> <dir3> ....
#   writes to current directory

# The goal is to be able to point this at a iPhoto/Picasa/Apature directory
# and collect up all the photos and ignore the garbage
# also just random directories full of photos.  We use hardlinks so we
# have a new collection of photos without lossing the original set.
# It would be nice to feel save to delete the original directories, but
# I need a couple items from the TODO list first.

# TODO
#   - Need option parser
#     - skip videos/pictures
#     - quiet
#   - Should save a log of all non-picture files skipped
#     (ignoring "normal" stuff like  .picasa.ini)
#   - When EXIF data can't be found look for other dates
#      iphoto puts date in directory names
#      .picasa.ini
#      file timestamp?  (often wrong)
#   - should we try to save other informaion like "sue's birthday" in file/dir
#     names?
#   - If we can't find a date it would be good to still save files
#   - if hardlinks fail switch to copy
#   - test on windows
#

use strict;

use File::Compare;
use File::Path;
use Image::ExifTool;
use File::Find;

my $exiftool = new Image::ExifTool;
$exiftool->Options(DateFormat => '%Y-%m-%d_%H%M%S');

my %seen;

my($dev, $ino) = stat(".");

find({ wanted => \&wanted, no_chdir => 1}, @ARGV);

sub wanted {
    my($xdev, $xino) = stat($_);
    my($file) = (/.*\/(.*)/)[0] || $_;

    # directories to prune
    if (($dev == $xdev && $ino == $xino) ||
	$file eq "Thumbnails" ||
	$file eq "Previews" ||
	$file eq "\@eaDir" ||
	$file =~ /AppleDouble$/) {

	$File::Find::prune = 1;
	return;
    }
    # XXX .gif & .png don't have exif data
    if (/\.(cr2|jpg|jpeg|tiff|avi|mov)$/i &&
	$file !~ /^\._/) {
	link_image($_);
    }
}

sub link_image {
	my($pic) = @_;
	my $date;
	my($dir, $file);

	my $info = $exiftool->ImageInfo($pic);

	if (!($date = ($info->{DateTimeOriginal} ||
		       $info->{CreateDate} ||
		       $info->{GPSDateTime})) ||
	    $date =~ /^000/) {
		warn "no time found in $pic\n";
		foreach (keys %$info) {
		    next unless /date|time/i;
		    next if $_ eq "FileModifyDate" || $_ eq "ProfileDateTime";
		    print "$_ => $$info{$_}\n" if /date/i;
		}
		return;
	}
	if ($date =~ /^0/) {
	    die "$date in $pic";
	}
	($dir = $date) =~ s/^(\d+)(.*)_.*/$1\/$1$2/;
	mkpath($dir) unless $seen{$dir} || -d $dir;
	$seen{$dir} = 1;

	my $ext;
	($ext = $pic) =~ s/.*\.(\w+)$/\L$1/i;
	$ext =~ s/jpeg/jpg/;
	die "$ext" unless $ext;

	$file = "$dir/$date.$ext";

	my($dev1, $ino1, $size1) = (stat($pic))[0, 1, 7];
 loop:
	my($dev2, $ino2, $size2) = (stat($file))[0, 1, 7];

	if (!$size2) {
		print "link($pic)\n";
		link $pic, $file ||
		    die "link($pic, $file) failed";
	} elsif ($dev1 == $dev2 && $ino1 == $ino2) {
		# already linked, ignore
		#print "already linked: $pic\n";
	} elsif ($size1 != $size2 || compare($pic, $file)) {
		# files different

	        # test if it differs by only EXIF data

		print "different: $pic $file\n";
		$file =~ s/_(\d{6})(_(\d+))?\.(\w+)$/_$1/;
		$file .= sprintf("_%d.$4", ($3 || 0) + 1);
		goto loop;
	} else {
		# not already linked but should be

	        # XXX we should compare nlink and creation time to
	        # decide which file gets replaced

		print "relink $pic\n";
		link $file, "$pic.tmp$$" ||
		    die "link($file $pic.tmp$$) failed";
		rename "$pic.tmp$$", $pic ||
		    die "rename($pic.tmp$$, $pic) failed";
	}
}

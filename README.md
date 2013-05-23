link_photos_bydate
==================

Find all unique photos in a directory and link into a directory by creation date.
Also hardlinks duplicate photos inplace so that duplicates in existing collections
will be collapsed together.

Usage
-----

link_photos_bydate.pl <dir1> <dir2> <dir3> ....


Walks all picture files in the directories on the command line looking for pictures.
Any pictures found are opened and the EXIF data is read.  The original date the
picture was taken is found and the files is linked to:

   YYYY/YYYY-MM-DD/YYYY-MM-DD.hh:mm:ss.jpg
   
in the current directory.  If multiple pictures are found that were taken in the same
second then the files are examined to see if they are in fact identical.  If not
then .<num> is added before the file extension.  If a duplicate is found, then that duplicate
is hardlinked to the same file so save disk space.


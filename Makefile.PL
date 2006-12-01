use 5.008004;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Alvis::Convert',
    VERSION_FROM      => 'lib/Alvis/Convert.pm', # finds $VERSION
						# e.g., Module::Name => 1.1
    PREREQ_PM         => {Encode => 0, Compress::Zlib => 0, Data::Dumper =>0 , XML::LibXML =>0 , XML::Parser =>0 , 
			  HTTP::Headers::Util =>0 , HTML::Encoding =>0 , File::Type =>0 , Parse::MediaWikiDump =>0 , 
		          Digest::MD5 =>0 ,  Cwd =>0 ,  File::Copy =>0 ,  File::Find =>0 ,  File::Path =>0 , 
   			  Getopt::Long =>0 ,  IO::Handle =>0 ,  Pod::Usage =>0 ,  POSIX =>0 ,  Time::HiRes => 0}, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Alvis/Convert.pm', # retrieve abstract from module
       AUTHOR         => 'Kimmo Valtonen <kimmo.valtonen@hiit.fi>') : ()),
    EXE_FILES    => [ 'bin/wikipedia2alvis.pl',
		      'bin/alvis_wikipedia_add_cats.pl',
		      'bin/news_xml2alvis.pl',
		      'bin/html2alvis.pl',
		      'bin/html2plain.pl',
		      'bin/ainodump2alvis.pl',
		      'bin/alvisDecollect.pl',
		      'bin/alvisXMLmerge.pl',
		      'bin/alvisXMLsplit.pl',
		      'bin/alvisXSL.pl',
		      'bin/alvisXMLjoin.pl'],

);

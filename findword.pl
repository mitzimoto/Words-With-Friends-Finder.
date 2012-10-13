#!/usr/bin/perl

#------------------------------------------------------------------------------#
# Script: findword.pl                                                          #
#                                                                              #
# Description: A tool to find possible words on a words with friends board that#
#              match a given regex pattern and list them in order of highest   #
#              points                                                          #
#                                                                              #
# Original author: Eric Mitz (http://ericmitz.com)                             #
#------------------------------------------------------------------------------#

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;

my $shelf;
my $pattern;
my $interactive;
my $words;
my $shelf_count = {};
my $pattern_map = {};
my @words;
my @patterns;

sub usage {

    my $script = basename($0);

    print <<END;

Useage: $script -s SHELF -p PATTERN [-i] [DICTIONARY]
A tool to find possible words on a words with friends board that match a given
regex pattern and sorts results by highest point values. Use the _ (underscore)
character as a wildcard.

SHELF     the current letters you currently have available to play
PATTERN   is a regex pattern to match against

Examples: 

  $script -s tkbdwne -p .*art\$ words.txt

Options:

    DICTIONARY              The word dictionary to use.  It should be a sorted
                            list of lowercase words, newline separated. Defaults
                            to ./words.txt.

    -i, --interactive       Input a list of patters to match. Terminate the list
                            by entering 'eof' on its own line. Cannot be used 
                            with -p
    -p, --pattern=PATTERN   The regex pattern to match against; required unless
                            -i is used.
    -s, --shelf=SHELF       The current letters you currently have available;
                            required.


END

}

#Get the command line options
GetOptions ( 
    's|shelf=s'     => \$shelf,
    'p|pattern=s'   => \$pattern,
    'i|interactive' => \$interactive
) or die ("Invalid options");

#validate command line options
die("Please specify a shelf") unless $shelf;
die("Please specify a pattern") unless $pattern or $interactive;

#If no dictionary file is specified, default to words.txt
my $WORDS   = $ARGV[0] || "words.txt";
my $ALPBT   = "abcdefghijklmnopqrstuvwxyz";

# Make sure the dictionary we're using actually exists
die ("Could not find word dictionary <$WORDS>") unless ( -f $WORDS );

#Point values for each letter. Source: http://www.words-with-friends-cheats.com/rules/letter-values
my $POINTS  = {
    'a' => 1,
    'b' => 4,
    'c' => 4,
    'd' => 2,
    'e' => 1,
    'f' => 4,
    'g' => 3,
    'h' => 3,
    'i' => 1,
    'j' => 10,
    'k' => 5,
    'l' => 2,
    'm' => 4,
    'n' => 2,
    'o' => 1,
    'p' => 4,
    'q' => 10,
    'r' => 1,
    's' => 1,
    't' => 1,
    'u' => 2,
    'v' => 5,
    'w' => 4,
    'x' => 8,
    'y' => 3,
    'z' => 10
};

sub check_pattern {

  # Checks if a given pattern matches a given word based on the alphabet we've
  # modified based on our shelf.

  my $input_pattern = shift;
  my $input_word    = shift;

  # Substitute the negative alphabet into the empty pattern spots. For example
  # if your board has P__L, you could use p..l as a pattern. We're basically
  # saying "Match any character except those in the shelf".
  $input_pattern =~ s/\./\[\^$ALPBT\]/g;

  # A little tricky. _ is the wild card for this script, but . is the general
  # regex wildcard so we have to replace all _'s with .'s before we match
  $input_pattern =~ s/\_/\./g; 

  #print "^${input_pattern}[^$ALPBT]*\$"; exit;

  if ( $input_word =~ /^${input_pattern}[^$ALPBT]*$/ ) {

    # If the word matches the pattern, add it to the glbal @words array.
    push( @words, $input_word );

    # We want to save a hash of which input pattern matched the word.
    # To do that we have to reverse the regex we did above
    $input_pattern =~ s/\[\^$ALPBT\]/\./g;
    $pattern_map->{$input_word} = $input_pattern;

  }

}

# Split the shelf array so we can access each individual letter
my @shelf_array = split('', $shelf);

# Remove all the shelf letters that we're given from the ALPBT string
foreach my $char (@shelf_array) {
  next if $char eq '_'; #Skip the wildcar character 
  $ALPBT =~ s/$char//g;
}

#Open the dictionary
open(my $WORD_FILE, "<$WORDS") or die ("Could not open <$WORDS>: $!");

#get all the input patterns
if ( $interactive ) {
  while( my $input_pattern = <STDIN> ) {
    chomp( $input_pattern );
    last if $input_pattern eq 'eof';
    push( @patterns, $input_pattern );
  }
}
else {
  #If -i is not used, the only pattern should be the one we get with -p
  push( @patterns, $pattern);
}

# For each pattern we have, search for the pattern in the dictionary based on
# the current shelf we were given.
foreach my $pattern_element ( @patterns ) {

  while( my $word = <$WORD_FILE> ) {
    chomp($word);
    check_pattern($pattern_element, $word);   
  }

  # Rewind the dictionary file so that we're always searching from the top
  # with each pattern we're checking.
  seek( $WORD_FILE, 0, 0);
}

# Count up the number of each letter we have since we can have more than one.
foreach my $shelf_letter ( @shelf_array ) {
  $shelf_count->{$shelf_letter}++;   
}

# check_pattern() will return matches regardles of whether we actually have enough
# tiles. This next section purges any matches from check_pattern() that we don't
# have enough of a given tile for.
#
# Using a for loop here because we need the index for delete.
for my $i ( 0 .. $#words ) {

  my $word = $words[$i];

  foreach my $shelf_letter ( @shelf_array ) {

    #Skip the wildcard
    next if $shelf_letter eq '_';

    # How many of this letter do we have in the shelf?
    my @letter_count  = ( $word =~ /$shelf_letter/g );

    # How many of this letter is in the pattern?
    my @pletter_count = ( $pattern_map->{$word} =~ /$shelf_letter/g );

    # If the number of letters we need is more than we have, delete this word
    # from the results.
    if ( ( @letter_count - @pletter_count ) > $shelf_count->{$shelf_letter}){
      delete $words[$i];
    }

  }

}

# calculate the estimated points value for the words we've matched.
foreach my $word (@words) {

    # Skip the words that have been deleted.
    next unless $word;

    # Split the word into its individual letters.
    my @word_array = split('', $word);

    my $word_total = 0;

    foreach my $char ( @word_array) {
        # Increment the point total.
        $word_total += $POINTS->{$char};
    }

    print "$word_total\t$word\n";
}

close $WORD_FILE;

exit


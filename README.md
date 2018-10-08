# Timex HiColour slideshow creator.
A small C utility that takes a series of SCR files containing two 6144 blocks that comprises a Timex HiColour screen and generates a PZX file with a slideshow of all of them.

Files are expected to be named scr01.scr, scr02.scr, scr03.scr, etc... Each of them must be a 12288 byte file containing two 6144 blocks: one with the bitmap data, stored in the usual Spectrum order, and the other one is the attribute data, which for a HiColour screen, it's stored with the same scheme as the Spectrum bitmap data.

For each SCR file, the utility merges both screens and add them to the PZX file so that each screen has one byte from the bitmap block, followed by one byte from the attribute block. Scanlines are shuffled so that the loading process appears to be linear, from top to bottom.

The utility stops processing SCR files when the next scrXX.scr file is not found.

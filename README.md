# Title: Timed Text Localization Engine

_Title_ simplifies the localization of timed text (subtitles, closed captions) using an innovative approach: it parses timed text files in various formats, generates recombined intermediate localization files with sentence-based segmentation, then compiles localized files back into timed text files in their original format.

It allows you to auto-import subtitles from external services such as YouTube and Vimeo, and generates video preview links for each translation segment.

# Status

**NOTICE: This software has a status of an early preview. It doesn't have all the functionality and documentation that an initial stable release is supposed to have, and its set of commands and their syntax are expected to change without ay notice and without backward compatibility. Use at your own risk.**

# Why use Title?

It may seem that it's much simpler to localize timed text files directly. After all, this is exactly how most localization tools work with timed text files: they parse such files and allow you to provide translations based on the initial cue segmentation. However, such segmentation, while being appropriate for time-based synchronization with media, doesn't make sense from the translation perspective, as the sentences are broken into smaller incomplete parts. This introduces various issues (more on that in _The problem, explained_ section below).

_Title_ approaches this challenge differently: it remembers the original cue positioning, but reconstructs the full sentences for easier translation. In other words, if a single sentence is broken into multiple parts in the original timed text file, it will be joined into a single translation segment. Once translations are completed, Title will take these translations and reconstruct the original segmentation.

## The problem, explained

Consider the following example: we have a timed text file in SRT format with these two entries among others:

_Source SRT file:_

```srt
1
00:00:03,240 --> 00:00:06,530
It’s rare to find
somebody who’s never seen

2
00:00:06,530 --> 00:00:08,920
a Star Wars film.

...
```

Here a single sentence is split into two parts. This is a common occurrence in timed text files, as the length of the text and the time it can be shown for is limited. Typical localization tools, when given such a source file, will render two independent segments for translation:

_Segment 1 (source language):_

    It’s rare to find
    somebody who’s never seen

_Segment 2 (source language):_

    a Star Wars film.

Now we want to translate this into some other language, where word ordering in a sentence is different. To keep the example understandable, let's translate it into an imaginary _Yōdā_ language, in which the same phrase sounds like this:

```
Sōmēbōdy whō’s nēvēr sēēn ā Stār Wārs fīlm tō fīnd īt’s rārē.
```

But how do you fit that phrase into two segments above? Since we're talking about timed text, what translators have to do is to split the phrase roughly matching the length of the original segments:

_Segment 1 (target language):_

    Sōmēbōdy whō’s nēvēr
    sēēn ā Stār Wārs fīlm

_Segment 2 (target language):_

    tō fīnd īt’s rārē.

What we now have in our translation memory database for Yōdā language is these two entries:

    Source: `It’s rare to find
    somebody who’s never seen`

    Target: `Sōmēbōdy whō’s nēvēr
    sēēn ā Stār Wārs fīlm`

and

    Source: `a Star Wars film.`

    Target: `tō fīnd īt’s rārē.`

Such isolated "translations" don't correspond to the source and thus:

1. Pollute translation memory (TM) with junk and cause issues with TM use in the future;
2. Trigger false positive linguistic checks, increasing the review time;
3. Slow down translation, as translators have to provide translation for a single phrase across multiple segments, sometimes going back and forth between them multiple times.

## The solution

_Title_ detects sentences that were broken apart, and reconstructs them into a single unit in the intermediate localization file:

    It’s rare to find
    somebody who’s never seen

    a Star Wars film.

Here the double line break between lines defines the original segmentation.

This combined segment is easy to translate as a whole, and easy to adjust the split position for:

    Sōmēbōdy whō’s nēvēr
    sēēn ā Stār Wārs fīlm

    tō fīnd īt’s rārē.

This single segment is what goes into the translation memory. Being a complete sentence, it makes perfect sense in Yōdā language, and can be reused in the future.

Once the translation is provided, what Title does next is it reconstructs the original segmentation and produces a localized timed text file in its original format:

_Localized SRT file:_

```srt
1
00:00:03,240 --> 00:00:06,530
Sōmēbōdy whō’s nēvēr
sēēn ā Stār Wārs fīlm

2
00:00:06,530 --> 00:00:08,920
tō fīnd īt’s rārē.

...
```

## Beyond re-segmentation

### Preview links

When Title generates intermediate localization files, it can also automatically generate comments for each segment. For videos imported from YouTube and Vimeo, the generated comment will have a preview link that will play the exact part of the video where the phrase appears (for Vimeo the link will only allow one to start playback from a given time). Such preview links are a great context for translators, and are supposed to work with a variety of CAT tools that are able to display comments.

### Separate time data

_Title_ deliberately separates localization files from files containing time data. This allows translators (or your localization automation infrastructure) to independently update localization files while another person is working on adjusting the timings, and avoid editing conflicts.

# Installation

Download and unpack this repo into any directory. Symlink `bin/title` to `/usr/local/bin/title` for easier access.

# Usage

## 1. Importing timed text from external services

You can automatically import subtitles from a public video service by creating a new folder that will contain subtitle files for that video, and then running the following command:

    $ title import <video-url>

This will import the default language defined for that particular video.

Currently supported video services are: YouTube and Vimeo.

### Example

    $ title import https://www.youtube.com/watch?v=fHmgF4ibmuk

or:

    $ title import https://youtu.be/fHmgF4ibmuk

And then in a separate folder:

    $ title import https://vimeo.com/358296408

Importing a video also initializes it for localization, so you don't need to do an explicit `title enable` step (see below).

## 2. Enabling localization of a specified source file

If you did not import a timed text file from YouTube, but put it manually in a separate folder on a disk, you need to enable its localization. This is done once for each source localization file. What this command does is that it creates a subfolder called `.title` in the same directory where the file exists, then a sub-folder that matches the file name, and places a default configuration file in it. Such timed text file now becomes a source localization file.

    $ title enable path/to/source-file.vtt

Initializing a timed text file also does an initial parsing (see the `title parse` step below).

### Example

    $ title enable en.vtt

This will create a `.title/en.vtt/config.json` file, and the source `en.vtt` file will be parsed for the first time.

## 3. Parsing source timed text files

Whenever a source file changes, it needs to be re-parsed to update source localization file and timing data. This is done with the following command:

    $ title parse [path/to/en.vtt]

An optional path parameter can point to a specific source file, or to a directory. If the parameter is omitted, a current directory is used. Specifying a directory means that all source timed text files in that directory and subdirectories will be processed.

Currently supported timed text file formats are: SRT (`.srt`) and WEBVTT (`.vtt`).

### Example

    $ title parse

The command above will scan for all timed text files in the current directory and subdirectories.

## 4. Building localized timed text files

Whenever localization files are updated, or timing data files are changed, you need to rebuild localized timed text files. This is done with the following command:

    $ title build [path/to/en.vtt]

As with the `parse` command above, you can specify a path to a specific file, or to a directory.

### Example

    $ title build

The command above will scan for all timed text files in the current directory and subdirectories, and build all available localizations for them.

# Questions / Comments?

Join the chat in Gitter: https://gitter.im/loctools/community

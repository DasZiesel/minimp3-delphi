minimp3-delphi
==========

A demo program for Delphi thats play mp3 files with DirectSound/OpenAl by using the famous [minimp3](https://github.com/lieff/minimp3) library built in. No external mp3 decoder required.

> For OpenAl playback make sure you have the required OpenAl libraries installed.

## How-to run

You need a copy of Delphi XE2 or greater. Just open the Project file and **Run**.

The demo program includes follow functionalities

> First select your Audio Renderer DirectShow or OpenAl. Then drag and drop a mp3 file into application container.

* Chunk Stream Play (DirectShow/OpenAl)
	* decodes the mp3 frame by frame to a small buffer and streams directly to a DirectSound/OpenAl buffer. Low Memory usage.
* Stream Play (DirectShow)
	* decodes the mp3 frame by frame into a buffer before playing and streams this to a DirectSound buffer. High Memory usage.
* Write to wav
	* decodes the mp3 file and writeout to a playable wave file.

#### Remarks

* Yes i know, the source miss some checks and cleanup steps.
* The DirectShow Playback is timer based and the OpenAl is thread based. Thats ***not*** renderer dependent, just different methods for streaming data. It can be exchanged between renderer.

## How-to build minimp3 library

To build a installed version of GCC 4.8.1 are required, use the batch ***buildmp3.bat*** that compile minimp3lib.cpp file.

### Remarks

> Builds works only with GCC v4.8.1 32-bit. Depends on required ***___chkstk_ms***. I took this from [lz4-delphi](https://github.com/Hugie/lz4-delphi), i have no idea how to extract this dependency from libgcc.a. Leave a comment if you know how to build the lib without or with other versions.

## Dependencies

 * minimp3
	* https://github.com/lieff/minimp3
 * lz4-delphi - only used chkstk_ms.obj
	* https://github.com/Hugie/lz4-delphi
 * OpenAl Headers for Delphi
	* https://www.noeska.com/doal/
# OBFileTransfer

[![CI Status](http://img.shields.io/travis/etcetc/OBFileTransfer.svg?style=flat)](https://travis-ci.org/etcetc/OBFileTransfer)
[![Version](https://img.shields.io/cocoapods/v/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)
[![License](https://img.shields.io/cocoapods/l/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)
[![Platform](https://img.shields.io/cocoapods/p/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)

OBFileTransfer provides simple foreground and background file upload and download services with retry to various data stores.  Currently only stores for standard
server, Amazon S3, and Google Cloud are provided.  The standard server store just means that the uploads and downloads are from a server using standard http or https get/post methods.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.  In Example directory see OBViewController.m for sample usage.
The program does need to know the configuration parameters for the storage that you will be using.  It's easiest to specify these in a file called config.plist, which you must add to the 
project.  A file called example-config.plist shows the parameters that are currently supported.  

To use the manager, you create a singleton OBFileTransferManager object, and then indicate that you want to upload or download one or more files, each of which you will identify using a marker.  The manager then starts transmitting or downloading the files
using a background service.  If you close the app while it's transmitting, it will continue the transfers, and will call back to the program with transfer progress status for the indicated marker.  This can be used to update the UI with progress bar or otherwise, and to indicate if the transfer completed or failed.

The library keeps track of requested transfers, and if the transfer fails for whatever reason, starts a retry timer.  The timer has a progressive backoff, so it will try again and again while its still running in the background.  

When the user brings the app back to the foreground, you should send the "retryPending" message to the manager to restart any tasks that were pending.  

The client (the OBViewController in the Example) must implement the OBFileTransferDelegate delegate methods, which currently are quite simply callbacks for getting information regarding the file transfer completion, progress, and indication of retry.

## Internals
The status of the transfers is persisted in a simple plist.  While this is nice because it's simple, it does mean that each time we change the status of a particular transfer we are rewriting all the transfer tasks to disk.  While this is OK for a small number of concurrent transfers, it may not be suitable if the app is sending a large number of small files, for example.


## Requirements
This depends on the OBLogger pod.  Please review OBLogger notes and consider when you want to reset the log file.

## Installation

OBFileTransfer will soon be available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "OBFileTransfer"

## Author

etcetc, ff@onebeat.com
Thanks for initial podification, bug fixes, and other contributions by Sani ElFishawy

## License

OBFileTransfer is available under the MIT license. See the LICENSE file for more info.


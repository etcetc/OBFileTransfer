# OBFileTransfer

[![CI Status](http://img.shields.io/travis/etcetc/OBFileTransfer.svg?style=flat)](https://travis-ci.org/etcetc/OBFileTransfer)
[![Version](https://img.shields.io/cocoapods/v/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)
[![License](https://img.shields.io/cocoapods/l/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)
[![Platform](https://img.shields.io/cocoapods/p/OBFileTransfer.svg?style=flat)](http://cocoadocs.org/docsets/OBFileTransfer)

OBFileTransfer provides simple foreground and background file upload and download services with retry to various data stores.  Currently only stores for standard
server and S3 are provided.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.  In Example directory see OBViewController.m for example usage.
Basically, you create a (currently singleton) OBFileTransferManager object, optionally set the base URL and upload and download directories (a convenience so files can be specified just as offsets to these directories, but not a requirement), and then indicate that you want to upload or download a file.  

The client (the OBViewController in the Example) must implement the OBFileTransferDelegate delegate methods, which currently are quite simply callbacks for getting information regarding the file transfer completion, progress, and indication of retry.

## Requirements

## Installation

OBFileTransfer will soon be available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "OBFileTransfer"

## Author

etcetc, ff@onebeat.com
Thanks for initial podification, bug fixes, and other contributions by Sani ElFishawy

## License

OBFileTransfer is available under the MIT license. See the LICENSE file for more info.


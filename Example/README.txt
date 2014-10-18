This example shows FTM in action downloading and uploading to the following storage models:
1) your own server
2) Amazon S3
3) Google cloud storage

To run the example you need to

1) Set up the configuration parameters for each of the storage elements you're interested in.
  A. S3
       i) set up the bucket
      ii) set up a Token Vending Machine
     iii) upload the files that are used in the download tests in the bucket using some S3 management app
      iv) configure the urls, bucket name, etc in OBViewController.m
  B. Google Cloud
     This app works with Google cloud only in the configuration where the bucket access control is set to be public
     for writing and the download files are set up to allow public reading
       i) set up the bucket and set the permissions to be public
      ii) set up the access controls
     iii) generate a server api key (not an IOS key, which doesn't work)
      iv) configure the bucket name, api key, etc. in the app
  C. Server
     You can run the npde-baed serer in the TestServer directory via 'node server.js'.  This runs on port 3000.  you can then specify the URL in the configuraiton parameters.


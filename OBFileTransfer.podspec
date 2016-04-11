#
# Be sure to run `pod lib lint OBFileTransfer.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "OBFileTransfer"
  s.version          = "0.9.3"
  s.summary          = "A simple library to transfer files in the background."
  s.description      = <<-DESC
                       The client (your application) can use OBFileTransfer to upload and downlaod files to a server or S3 repository (S3 repository assumes AWS Token Vending Machine for authentication).  It can perform these uploads and downloads in the background so when the user switches apps it will still continue the transfers.  It is designed to be "best-effort", such that if there is an error, it will keep retrying some set number of times (or indefinitely as specified).

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/etcetc/OBFileTransfer"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "etcetc" => "ff@onebeat.com" }
  s.source           = { :git => "https://github.com/etcetc/OBFileTransfer.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*.{m,h}'
  s.resources = 'Pod/Assets/*'
# Create our own resource bundle so as to not pollute the including client
#  s.ios.resource_bundle = { "OBFileTransfer-ios" => ["Pod/Assets/*"] }
  s.public_header_files = 'Pod/Classes/**/*.h'
  s.vendored_frameworks = 'AWSRuntime.framework', 'AWSS3.framework'

s.dependency 'OBLogger'

end

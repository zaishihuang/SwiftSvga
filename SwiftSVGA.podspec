#
# Be sure to run `pod lib lint SwiftSVGA.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SwiftSVGA'
  s.version          = '1.0.0'
  s.summary          = 'A short description of SwiftSVGA.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Swift.SVGA 详情 https://github.com/svga/SVGAPlayer-iOS
                       DESC

  s.homepage         = 'https://github.com/zaishihuang/SwiftSVGA'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zaishi' => 'zaishi.huang@gmail.com' }
  s.source           = { :git => 'https://github.com/zaishihuang/SwiftSVGA.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'SwiftSVGA/Classes/**/*.swift', 'SwiftSVGA/Classes/**/*'
  s.dependency 'SwiftProtobuf'
  s.dependency 'ZIPFoundation'
  
  s.requires_arc = true
  s.swift_versions = ['4.0', '4.2', '5.0']
  
  # s.resource_bundles = {
  #   'SwiftSVGA' => ['SwiftSVGA/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end

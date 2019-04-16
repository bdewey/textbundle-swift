Pod::Spec.new do |s|
  s.name             = 'TextBundleKit'
  s.version          = '0.5.0'
  s.summary          = 'A Swift library for manipulating Textbundle packages (http://textbundle.org).'
  s.swift_version    = '4.0'

  s.description      = <<-DESC
  textbundle-swift is a pure-Swift library for reading and writing Textbundle packages.
  See http://textbundle.org
  Please note this is INCREDIBLY early in its development :-)
                       DESC

  s.homepage         = 'https://github.com/bdewey/textbundle-swift'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'bdewey@gmail.com' => 'bdewey@gmail.com' }
  s.source           = { :git => 'https://github.com/bdewey/textbundle-swift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.source_files = 'textbundle-swift/Classes/**/*'
  s.test_spec 'unit' do |test_spec|
    test_spec.source_files = 'textbundle-swift/Tests/**/*'
    test_spec.resource_bundles = {
      'TestContent' => 'textbundle-swift/TestContent/*',
    }
  end
end

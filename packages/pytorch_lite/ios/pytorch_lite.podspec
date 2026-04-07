#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pytorch_lite.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pytorch_lite'
  s.version          = '1.1.2'
  s.summary          = 'Flutter PyTorch Lite — classification and object detection'
  s.description      = 'Run PyTorch Lite (.ptl) models on-device for classification and detection'
  s.homepage         = 'https://github.com/zezo357/pytorch_lite'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'zezo357' => 'zezo357@github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'LibTorch-Lite-Nightly'
  s.platform = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'HEADER_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/LibTorch-Lite-Nightly/install/include'
  }
  s.swift_version = '5.0'
end

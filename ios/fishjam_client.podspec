Pod::Spec.new do |s|
  s.name             = 'fishjam_client'
  s.version          = '0.31.0'
  s.summary          = 'Fishjam client SDK for Flutter.'
  s.description      = <<-DESC
Fishjam client SDK for Flutter. Join Fishjam rooms and exchange real-time
audio, video and data from iOS and Android apps.
                       DESC
  s.homepage         = 'https://fishjam.io'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Fishjam' => 'hello@fishjam.io' }
  s.source           = { :path => '.' }
  s.source_files = 'fishjam_client/Sources/fishjam_client/**/*'
  s.dependency 'Flutter'
  # The WebRTC symbols come from flutter_webrtc's static framework, so this pod must be static too.
  s.static_framework = true
  # Picture-in-picture imports WebRTC. No version here: CocoaPods uses the
  # WebRTC-SDK pin from flutter_webrtc (150.7871.01 in flutter_webrtc 1.6.2).
  s.dependency 'flutter_webrtc'
  s.dependency 'WebRTC-SDK'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

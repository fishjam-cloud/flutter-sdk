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
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

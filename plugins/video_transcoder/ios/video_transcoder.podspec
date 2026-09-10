Pod::Spec.new do |s|
  s.name             = 'video_transcoder'
  s.version          = '1.0.0'
  s.summary          = 'Native HDR to SDR video transcoder'
  s.description      = 'Uses AVFoundation on iOS to convert HDR/Dolby Vision to SDR H.264.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Foviox' => 'dev@foviox.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'CoreMedia', 'CoreVideo', 'CoreImage'
end

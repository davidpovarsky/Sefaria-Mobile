Pod::Spec.new do |s|
  s.name         = 'SpotlightIndexer'
  s.version      = '0.1.0'
  s.summary      = 'CoreSpotlight bridge for Sefaria Reader'
  s.description  = 'A small React Native bridge that indexes Sefaria source index items in iOS Spotlight.'
  s.homepage     = 'https://www.sefaria.org'
  s.license      = { :type => 'MIT' }
  s.author       = { 'Sefaria Reader' => 'hello@sefaria.org' }
  s.platforms    = { :ios => '15.5' }
  s.source       = { :path => '.' }
  s.source_files = '*.{h,m}'
  s.frameworks   = 'CoreSpotlight'
  s.dependency 'React-Core'
end

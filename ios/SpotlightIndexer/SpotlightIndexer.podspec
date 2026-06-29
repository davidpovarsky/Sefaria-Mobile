Pod::Spec.new do |s|
  s.name         = 'SpotlightIndexer'
  s.version      = '0.2.0'
  s.summary      = 'Spotlight and App Intents bridge for Sefaria Reader'
  s.description  = 'React Native bridge plus App Intents shortcuts for Sefaria source search, refs, app state, and Spotlight indexing.'
  s.homepage     = 'https://www.sefaria.org'
  s.license      = { :type => 'MIT' }
  s.author       = { 'Sefaria Reader' => 'hello@sefaria.org' }
  s.platforms    = { :ios => '15.5' }
  s.source       = { :path => '.' }
  s.source_files = '*.{h,m,swift}'
  s.swift_version = '5.0'
  s.frameworks   = 'CoreSpotlight', 'AppIntents', 'UIKit'
  s.dependency 'React-Core'
end

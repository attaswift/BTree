Pod::Spec.new do |spec|
    spec.name         = 'BTree'
    spec.version      = '4.1.0'
    spec.osx.deployment_target = "10.9"
    spec.ios.deployment_target = "8.0"
    spec.tvos.deployment_target = "9.0"
    spec.watchos.deployment_target = "2.0"
    spec.summary      = 'Fast ordered collections for Swift using in-memory B-trees'
    spec.author       = 'Károly Lőrentey'
    spec.homepage     = 'https://github.com/attaswift/BTree'
    spec.license      = { :type => 'MIT', :file => 'LICENSE.md' }
    spec.source       = { :git => 'https://github.com/attaswift/BTree.git',
                          :tag => 'v' + String(spec.version) }
    spec.source_files = 'Sources/*.swift'
    spec.social_media_url = 'https://twitter.com/lorentey'
    spec.documentation_url = 'http://attaswift.github.io/BTree/api/'
end

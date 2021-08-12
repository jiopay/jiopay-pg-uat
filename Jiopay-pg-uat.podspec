Pod::Spec.new do |spec|

  spec.name         = "Jiopay-pg-uat"
  spec.version      = "0.0.2"
  spec.summary      = "Library for accessing UAT jiopay payment checkout"
  
  spec.description  = <<-DESC
    This Library implements the pod for Jiopay payment checkout.
                   DESC

  spec.homepage     = "https://cocoapods.org/pods/Jiopay-pg-uat"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"

  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Prashant Dwivedi" => "prashant1.dwivedi@ril.com" }
  # Or just: spec.author    = "Prashant Dwivedi"
  # spec.authors            = { "Prashant Dwivedi" => "prashant1.dwivedi@ril.com" }

  spec.platform     = :ios
  spec.ios.deployment_target = "14.0"
  spec.swift_version = "4.2"

  spec.source       = { :git => "https://github.com/jiopay/jiopay-pg-uat.git", :tag => "#{spec.version}" }
  spec.source_files  = "jiopay-pg-uat/**/*.{h,m,swift}"
  #spec.source_files  = "Classes", "Classes/**/*.{h,m}"
  #spec.exclude_files = "Classes/Exclude"
end

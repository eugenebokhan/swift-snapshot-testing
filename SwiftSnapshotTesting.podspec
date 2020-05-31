Pod::Spec.new do |s|
  s.name = "SwiftSnapshotTesting"
  s.version = "0.0.1"

  s.summary = "Swift Snapshot Testing"
  s.homepage = "https://github.com/eugenebokhan/SwiftSnapshotTesting"

  s.author = {
    "Eugene Bokhan" => "eugenebokhan@protonmail.com"
  }

  s.ios.deployment_target = "12.0"

  s.source = {
    :git => "https://github.com/eugenebokhan/SwiftSnapshotTesting.git",
    :tag => "#{s.version}"
  }
  s.source_files = "Sources/**/*.{swift}"

  s.swift_version = "5.2"

  s.pod_target_xcconfig = { 'ENABLE_BITCODE' => 'NO' }
  
  s.dependency "ResourcesBridge"
  s.dependency "Alloy/Shaders"
  s.frameworks = "XCTest","UIKit","Foundation","QuartzCore"
end

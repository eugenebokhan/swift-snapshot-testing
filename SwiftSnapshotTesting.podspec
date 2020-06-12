Pod::Spec.new do |s|
  s.name = "SwiftSnapshotTesting"
  s.version = "0.1.0"

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

  s.swift_version = "5.2"

  s.pod_target_xcconfig = { 'ENABLE_BITCODE' => 'NO' }

  s.subspec 'Device' do |device|
    device.source_files = "Sources/**/*.{swift}"
    device.dependency "ResourcesBridge", "~> 0.0.1"
    device.dependency "Alloy/Shaders", "~> 0.14.2"
    device.frameworks = "XCTest","UIKit","Foundation","QuartzCore"
  end
  
  s.subspec 'Simulator' do |simulator|
    simulator.source_files = "Sources/**/*.{swift}"
    simulator.dependency "Alloy/Shaders", "~> 0.14.2"
    simulator.frameworks = "XCTest","UIKit","Foundation","QuartzCore"
  end
  
  s.default_subspec = "Device"
  
end

Pod::Spec.new do |s|
  s.name             = 'EGBaseSwift'
  s.version          = '1.0.0'
  s.summary          = 'EGBaseSwift - Swift 基础工具库'
  s.description      = <<-DESC
  EGBaseSwift 提供了常用的 Swift 扩展和工具类，包括：
  - 常用类型扩展
  - 国际化支持
  - UI 工具类
  DESC

  s.homepage         = 'https://github.com/YourUsername/EGBaseSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'YourName' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/YourUsername/EGBaseSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.9'

  # 源文件
  s.source_files = 'Sources/**/*.swift'

  # 框架
  s.frameworks = 'UIKit', 'Foundation'

  # 如果需要支持 SPM 和 CocoaPods 双重发布
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end

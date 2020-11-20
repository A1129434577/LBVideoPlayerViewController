Pod::Spec.new do |spec|
  spec.name         = "LBVideoPlayerViewController"
  spec.version      = "1.0.0"
  spec.summary      = "视频播放器"
  spec.description  = "一个超轻量级的视频播放器，支持屏幕旋转、手动旋转。"
  spec.homepage     = "https://github.com/A1129434577/LBVideoPlayerViewController"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "刘彬" => "1129434577@qq.com" }
  spec.platform     = :ios
  spec.ios.deployment_target = '8.0'
  spec.source       = { :git => 'https://github.com/A1129434577/LBVideoPlayerViewController.git', :tag => spec.version.to_s }
  spec.dependency     "AFNetworking"
  spec.dependency     "LBCommonComponents"
  spec.resource     = "LBVideoPlayerViewController/**/*.bundle"
  spec.source_files = "LBVideoPlayerViewController/**/*.{h,m}"
  spec.requires_arc = true
end
#--use-libraries
# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Telnyx Meet' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Telnyx Meet
  pod 'TelnyxVideoSdk', '~>0.3.6-beta11'
  
  # We need to have the same build settings across our dependencies in order to succesfully build our xcframework
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # To install pod dependencies when the app ins installed, this prevents us from getting:
        # dyld: Symbol not found error in runtime.
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        # To install pod dependencies when the app ins installed, this prevents us from getting
        # dyld: Symbol not found error in runtime.
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'

        # All the targets' products are copied into the archive
        config.build_settings['SKIP_INSTALL'] = 'NO'
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        config.build_settings['ENABLE_BITCODE'] = 'NO'

        # GoggleWebRTC doesn't support arm64
        # build libraries only for supported architectures.
        config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
        xcconfig_path = config.base_configuration_reference.real_path
      end
    end
  end

end

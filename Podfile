# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Telnyx Meet' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Telnyx Meet
  pod 'TelnyxVideoSdk', '~> 0.3.2'

  # We need to have the same build settings across our dependencies in order to succesfully build our xcframework
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # To install pod dependencies when the app ins installed, this prevents us from getting:
        # dyld: Symbol not found error in runtime.
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end

end

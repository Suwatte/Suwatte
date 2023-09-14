# Uncomment the next line to define a global platform for your project
 platform :ios, '15.0'

target 'Suwatte (iOS)' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod "Texture"

  # Pods for Suwatte (iOS)

end

post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
               end
          end
   end
end

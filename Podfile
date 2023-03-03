workspace 'TMTProject'
project 'TeXtended/TeXtended.xcodeproj'
project 'TMTBibTexTools/TMTBibTexTools.xcodeproj'
project 'TMTHelperCollection/TMTHelperCollection.xcodeproj'
project 'MMTabBarView/MMTabBarView/MMTabBarView.xcodeproj'
project 'TMTLatexTableFramework/TMTLatexTableFramework.xcodeproj'

platform :osx, '10.9'

target :TMTHelperCollection do
  project 'TMTHelperCollection/TMTHelperCollection.xcodeproj'
  pod 'CocoaLumberjack'
end

target :TMTBibTexTools do
  project 'TMTBibTexTools/TMTBibTexTools.xcodeproj'
  pod 'CocoaLumberjack'
  pod 'TMTHelperCollection', :path => './TMTHelperCollection'
end
target :DBLPTool do
  project 'TMTBibTexTools/TMTBibTexTools.xcodeproj'
  pod 'TMTBibTexTools', :path => './TMTBibTexTools'
  pod 'CocoaLumberjack'
  pod 'TMTHelperCollection', :path => './TMTHelperCollection'
end


target :TMTLatexTableExample do
  project 'TMTLatexTableFramework/TMTLatexTableFramework.xcodeproj'
  pod 'TMTLatexTable', :path => './TMTLatexTableFramework'
end

target :TMTLatexTableFramework do
  project 'TMTLatexTableFramework/TMTLatexTableFramework.xcodeproj'
  pod 'CocoaLumberjack'
  pod 'TMTHelperCollection', :path => './TMTHelperCollection'
end

target :TeXtended do
  project 'TeXtended/TeXtended.xcodeproj'
  pod 'CocoaLumberjack'
  pod 'DMInspectorPalette', '0.0.1'
  pod 'OTMXAttribute', '0.0.3'
  pod 'JSONKit-NoWarning', '1.2'
  pod 'Sparkle'
  pod 'TMTHelperCollection', :path => './TMTHelperCollection'
  pod 'TMTBibTexTools', :path => './TMTBibTexTools'
end

target 'TeXtended Tests' do
  project 'TeXtended/TeXtended.xcodeproj'
  pod 'Kiwi'
end


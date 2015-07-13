Pod::Spec.new do |s|
  s.name          = "TUPMediaKeyEventMonitor"
  s.version       = "1.0.2"
  s.summary       = "Monitor global key events for media keys."

  s.description   = <<-DESC
		    The `TUPMediaKeyEventMonitor` can monitor keypresses to the media keys even if the
	            application is not frontmost.  It will prevent conflicts with other applications
	            implementing media key monitoring using `TUPMediaKeyEventMonitor` and also has a
                    whitelist of applications implementing SPMediaKeyTap (which inspired 
                    TUPMediaKeyEventMonitor).
                    DESC

  s.homepage      = "http://github.com/tupil/TUPMediaKeyEventMonitor"
  s.license       = "BSD"
  s.author        = { "Eelco Lempsink" => "eml@tupil.com" }
  s.platform      = :osx, 10.9
  s.source        = { :git => "https://github.com/tupil/TUPMediaKeyEventMonitor.git", :tag => "#{s.version}" }
  s.source_files  = "*.{h,m}"
  s.frameworks    = "IOKit"
  s.requires_arc  = true
end

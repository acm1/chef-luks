name             'luks'
maintainer       'Intoximeters, Inc'
maintainer_email 'devops@intoxitrack.net'
license          'Apache 2.0'
description      'Installs/Configures LUKS block encryption'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

%w{centos redhat scientific fedora amazon}.each do |os|
  supports os
end

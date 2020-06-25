Initial Readme

objdump -p influxd | grep NEEDED

This will give you a list of requirements


check validity of deb

lintian -i -I --show-overrides influxd_folder.deb

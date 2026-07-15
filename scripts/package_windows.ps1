New-Item -ItemType Directory -Force -Name "out"

# windows setup
# Get-ChildItem -Recurse -File -Path "dist" -Filter "*windows-setup.exe" | Copy-Item -Destination "dist\tmp\BflyVPN-setup.exe" -ErrorAction SilentlyContinue
# Compress-Archive -Force -Path "dist\tmp\BflyVPN-setup.exe",".github\help\mac-windows\*.url" -DestinationPath "out\BflyVPN-windows-x64-setup.zip"
Get-ChildItem -Recurse -File -Path "dist" -Filter "*windows-setup.exe" | Copy-Item -Destination "out\BflyVPN-Windows-Setup-x64.exe" -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -File -Path "dist" -Filter "*windows.msix" | Copy-Item -Destination "out\BflyVPN-Windows-x64.msix" -ErrorAction SilentlyContinue


# windows portable
Get-ChildItem -Recurse -File -Path "dist" -Filter "*windows.zip" | Copy-Item -Destination "out\BflyVPN-Windows-Portable-x64.zip" -ErrorAction SilentlyContinue

Remove-Item -Path "$HOME\.pub-cache\git\cache\flutter_circle_flags*" -Force -Recurse -ErrorAction SilentlyContinue

echo "Done"

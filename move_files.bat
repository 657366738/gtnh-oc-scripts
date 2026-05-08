@echo off
set source=C:\Users\xiang\Desktop\oc_program
set dest=C:\Users\xiang\AppData\Roaming\ShatteredPrism\instances\GTNH284\.minecraft\saves\新的世界\opencomputers\ad53a602-7692-4fc8-9601-9c56bad41ad7\home
mkdir "%dest%" 2>nul
robocopy "%source%\*" "%dest%" /move /e
echo Files moved successfully.
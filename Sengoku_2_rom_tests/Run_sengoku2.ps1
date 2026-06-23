# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Set the path to the MAME executable (adjust if your exe name is different)
$mameExe = Join-Path $scriptDir "mame.exe"

# Run MAME in debug mode for dengoku2
# -debug: Launches the MAME debugger interface
# dengoku2: The short name for the game
& $mameExe -debug sengoku2
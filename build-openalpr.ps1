# Set the path to the OpenALPR source directory
$sourceDir = "C:\Users\HarelY\Documents\Projects\FCloud\NewBonusProject\LicensePlateRecognitionProject\OpenALPRSource\openalpr-2.3.0\src\openalpr"

# Set the path to the build directory
$buildDir = "$sourceDir\build"

# Create the build directory if it doesn't exist
if (-Not (Test-Path -Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir
}

# Navigate to the build directory
Set-Location -Path $buildDir

# Run CMake to generate Visual Studio 2022 project files
cmake .. -G "Visual Studio 17 2022" -A x64

# Build the solution using MSBuild
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" "OpenALPR.sln" /p:Configuration=Release 
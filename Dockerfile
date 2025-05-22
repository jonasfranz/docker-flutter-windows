# escape=`

# Create a windows container and install VisualStudio in it.
# This part is based on the official example from Microsoft.
# https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2022
FROM ghcr.io/jonasfranz/docker-images-windows:2022

# Defione the version of flutter, which will be installed in the container.
ARG FLUTTER_VERSION=3.27.3
ARG PWSH_VERSION=7.2.2

# Install VS
## https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019

## Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

## Download the Build Tools bootstrapper.
ADD https://aka.ms/vs/16/release/channel C:/TEMP/VisualStudio.chman

ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:/TEMP/vs_buildtools.exe
## https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2019
RUN C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache \
    --channelUri C:\TEMP\VisualStudio.chman \
    --installChannelUri C:\TEMP\VisualStudio.chman \
    --add Microsoft.VisualStudio.Component.Windows10SDK.19041 \
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    --add Microsoft.VisualStudio.Component.VC.CMake.Project \
    --add Microsoft.VisualStudio.Workload.NativeDesktop \
    --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --add Microsoft.VisualStudio.Component.VC.CLI.Support \
    --installPath C:\BuildTools \
     || IF "%ERRORLEVEL%"=="3010" EXIT 0

# Install Google Root R1 cert so pub.dartlang.org stays working

ADD https://pki.goog/repo/certs/gtsr1.pem C:/TEMP/gtsr1.pem
RUN powershell.exe -Command \
        Import-Certificate -FilePath C:\TEMP\gtsr1.pem -CertStoreLocation Cert:\LocalMachine\Root

# Install Flutter

RUN setx path "%path%;C:\flutter\bin;C:\flutter\bin\cache\dart-sdk\bin;"

RUN git clone -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git C:\flutter

RUN flutter config --no-analytics

RUN flutter config --enable-windows-desktop


RUN flutter doctor -v

# Install pwsh. This is the default shell expected by the windows gitlab runner for docker images.
# If it is not installed, gitlab-runner is not able to use the image.
# The installation procedure has been copied from the official gitlab-runner-helper image.
# https://gitlab.com/gitlab-org/gitlab-runner/-/blob/main/dockerfiles/runner-helper/Dockerfile.x86_64_servercore
#
# The download is performed using powershell.
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
# TLS1.2 has to enabled to download pwsh installer from GitHub.
RUN New-Item -ItemType directory -Path C:\Downloads; `
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; `
    Invoke-Webrequest "https://github.com/PowerShell/PowerShell/releases/download/v${Env:PWSH_VERSION}/PowerShell-${Env:PWSH_VERSION}-win-x64.msi" -OutFile C:\Downloads\pwsh.msi -UseBasicParsing

# Run the installer and remove it afterwards.
SHELL ["cmd", "/S", "/C"]
RUN msiexec.exe /package "C:\Downloads\pwsh.msi" /quiet REGISTER_MANIFEST=1 && `
    rmdir /s /q "C:\Downloads"
RUN pwsh --version

name: Build Windows EXE
on:
workflow_dispatch: # Позволяет запускать сборку вручную кнопкой
push:
branches: [ main, master ] # Запуск при пуше в главную ветку

jobs:
build:
runs-on: windows-latest
steps:
- name: Checkout code
uses: actions/checkout@v4

- name: Install Flutter
uses: subosito/flutter-action@v2
with:
channel: 'stable'
cache: true # Ускоряет повторные сборки

- name: Enable Windows support
run: flutter config --enable-windows-desktop

- name: Get dependencies
run: flutter pub get

- name: Build Windows Release
run: flutter build windows --release

- name: Upload Artifact
uses: actions/upload-artifact@v4
with:
name: flutter-windows-app
path: build/windows/x64/runner/Release/
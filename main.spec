# -*- mode: python -*-
import os
from PyInstaller.utils.hooks import collect_submodules, collect_data_files
import os

block_cipher = None

hiddenimports = collect_submodules('PyQt6')

# Include PyQt6 plugin folders
datas = collect_data_files('PyQt6')
datas += collect_data_files('PyQt6', subdir='Qt6/plugins/platforms')
datas += collect_data_files('PyQt6', subdir='Qt6/plugins/imageformats')
datas += collect_data_files('PyQt6', subdir='Qt6/qml')
datas += collect_data_files('PyQt6', subdir='Qt6/plugins/qmltooling')  # Optional

# Your project files
project_datas = [
    ('main.qml', '.'),
    ('resources.qrc', '.'),
]

datas += project_datas

excludes=[
    'PyQt6.QtWebEngineCore',
    'PyQt6.Qt3DCore',
    'PyQt6.Qt3DRender',
    'PyQt6.QtSql',
    'PyQt6.QtWebView',
    'PyQt6.QtPositioning',
    'PyQt6.QtPdf',
    'PyQt6.QtSensors',
    'PySide6'
]

a = Analysis(
    ['main.py'],
    pathex=[os.getcwd()],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='OpenMOTIONTestApp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,  # Change to True for debugging
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    name='OpenMOTIONTestApp',
)

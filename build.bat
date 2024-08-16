@echo off
chcp 65001

IF "%1"=="help" (
    echo.
    echo Usage: build.bat ^[command^]
    echo.
    echo  ^[command^]:
    echo     release     默认，打包到package_example文件夹
    echo     dev         打包到build文件夹，并上传至手机调试
    echo     help        显示这个帮助菜单
    echo.
    exit
)


IF "%1"=="dev" (
    echo =================================================================
    copy build_info.cfg .\asset\sh\build_info.sh
    echo BUILD_DATE="%date% %time%">>.\asset\sh\build_info.sh
    .\build_tool\dos2unix.exe .\asset\sh\*
    .\build_tool\7z.exe a -tzip -bb3 .\build\test.zip asset META-INF
    .\build_tool\adb.exe push .\build\test.zip /tmp
    
    echo.
    echo ==.\build\test.zip===============================================Build OK
    exit
)

IF "%1"=="release" (
    echo =================================================================
    copy build_info.cfg .\asset\sh\build_info.sh
    echo BUILD_DATE="%date% %time%">>.\asset\sh\build_info.sh
    .\build_tool\dos2unix.exe .\asset\sh\*
    .\build_tool\7z.exe a -tzip -bb3 .\package_example\install.zip asset META-INF
    echo.
    echo ==.\package_example\install.zip==================================Build OK
    exit
)

echo 未知的命令：%1
echo 使用.\builid.bat help了解更多详细
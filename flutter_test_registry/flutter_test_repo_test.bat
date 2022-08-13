PUSHD attributed_text
CALL flutter test || GOTO :END
POPD

PUSHD super_editor
CALL flutter test || GOTO :END
POPD

PUSHD super_text_layout
CALL flutter test || GOTO :END
POPD

@ECHO.
@ECHO.
@ECHO Testing complete.
GOTO :EOF

:END
@ECHO.
@ECHO.
@ECHO Testing failed.
EXIT /B 1

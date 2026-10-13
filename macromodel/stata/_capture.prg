' Program: _capture.prg
' Purpose: Execute command that might result in an error; 
' Usage: exec _capture.prg "COMMAND"
'        where the argument is an EViews command string

%command = {%0}

setmaxerrs 2
{%command}
clearerrs
setmaxerrs 1

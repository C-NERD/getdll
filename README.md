# Getdll

Cmdline based tool for dealing with windows application dll dependencies

## Compilation

To compile this application you'll need

* nim compiler

navigate to the projects root directory and type

```bash
nimble build -d:danger -d:release -d:ssl --gc:arc
```


## Note

This project will only compile for the windows os but, if you wish to test this on any other os you can simple comment out the first three lines of the file getdll.nim

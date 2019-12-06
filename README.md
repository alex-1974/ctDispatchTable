# Create a dispatch table at compile time in dlang

[Wikiquote](https://en.wiktionary.org/wiki/dispatch_table)
> A table of pointers to functions or methods, commonly used to implement dynamic binding. 

Tested with dmd (2.085.1) and ldc2 (1.17.0)

A simple dispatch table example: 
```D
    string fnDef (string s) { return s; }
    string fnA (string s) { return s; }
    string fnB (string s) { return s; }

    auto dispatch (string name) {
        switch (name) {
            default: return fnDef;
            case "a": return &fnA;
            case "b": return &fnB;
        }
    }

    assert (dispatch("a")("passed") == "passed");
```

## Usage:

The same dispatch table as above
```D
    import std.meta;
    alias list = AliasSeq!("a", fnA, "b", fnB);
    mixin(dispatchTable!("dtable", string, string).With!(fnDef, list));
    assert (dtable("a")("passed") == "passed");
```

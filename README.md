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

## Parameters:

```D
    dispatchTable!("nameOfTable", returnType, parameterType1, parameterType2, ...).With!(defaultFunction, value1, func1, value2, func2, ...)
```

If the dispatched functions are part of an overloaded set, we need their signature to find the right ones. And we use the signature to test if all functions have the same return type and parameter types.
The default function is used, if the value is not found (switch-case default). If null we return null as default.
The switch-cases are given as a list of value-function pairs. The value must be a string, a char or a numeric type. Duplicates are not allowed.

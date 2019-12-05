/** Gives you a symbol’s name as a string.

    Stringof sometimes behaves weird and gives fn() instead of fn.
    Note that this works for many (all?) kinds of symbols: template names, class
    names, even modules:
**/
template nameOf(alias a) {
    enum string nameOf = __traits(identifier, a);
}
/** **/
unittest {
    int foo(int i, int j) { return i+j;}
    enum name = nameOf!foo; // name is available at compile-time
    assert(name == "foo");
}
/** Get every even argument from the list **/
template getEven (Args...) {
    import std.meta: Stride;
    alias getEven = Stride!(2,Args[0..$]);
}
/** Get every uneven argument from the list **/
template getUneven (Args...) {
    import std.meta: Stride;
    alias getUneven = Stride!(2,Args[1..$]);
}

template getOverload (alias func, RT, PT...) {
    import std.traits;
    import std.meta;
    import std.algorithm;
    import std.stdio;
    // Helper for std.meta.Filter
    template match (alias f) {
        static if (is(ReturnType!f == RT) && is(Parameters!f == PT)) enum match = true;
        else enum match = false;
    }
    // is the function overloaded?
    static if (isOverloaded!func) {

        alias f = Filter!(match ,__traits(getOverloads, __traits(parent, func), nameOf!func));
        static if (!f.length) static assert (0, "No matching overload " ~ RT.stringof ~ " " ~ nameOf!func ~ "(" ~ PT.stringof ~ ") exists!");
        else enum getOverload = &f[0];  // we get a list retour but we know the first is the one we need
    }
    else static if (match!func) {
        enum getOverload = &func;
    }
    else {
        static assert(0, "No function " ~ RT.stringof ~ " " ~ nameOf!func ~ "(" ~ PT.stringof ~ ") exists!");
    }
}
/** Check if function is overloaded **/
template isOverloaded (alias func) {
    static if (__traits(getOverloads, __traits(parent, func), nameOf!func).length > 1)
        enum isOverloaded = true;
    else
        enum isOverloaded = false;
}

// We can't overload functions inside unittests
// So these functions are solemnly for unittestings
string fn (string s) { return s; }
int fn (int i) { return i; }
bool fn (bool b) { return b; }
long fn2 (long l) { return l; }
string fn3 (string s) { return s; }

unittest {
    import std.stdio;
    static assert (isOverloaded!fn);
    static assert (!isOverloaded!fn2);
    //auto f = getOverload!(int, int, fn)();
    //writefln ("%s", f(3));
}

/** Create a dispatch table at compile time

    ---
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
    ---
    Params:
        name = Name of dispatch table
        RT = Return type
        PT = Parameter types
**/
template dispatchTable (string name, RT, PT...) {
    import std.traits;
    import std.typecons;
    /**
        Params:
          defFn = Function for default case
          Args = List of name and functions
    **/
    template With (alias defFn, Args...) {
        static assert (validArgs!(Args), "Invalid Arguments!");
        static assert (isFunction!defFn || is(typeof(defFn) == typeof(null)), "Invalid default function!");

        enum string With = "auto " ~ name ~ " (" ~ typeof(Args[0]).stringof ~ " value) {\n"
                                ~ "  switch (value) {\n"
                                ~ "    " ~ buildDefault!(defFn, RT, PT) ~ "\n"
                                ~ buildCases!(RT, PT).With!(Args)
                                ~ "  }\n"
                                ~ "}\n";
        pragma(msg, "Result of dispatchTable:\n" ~ With);
    }

}
/** **/
unittest {
    import std.meta;
    alias list = AliasSeq!("eins", fn3);
    mixin(dispatchTable!("table", string, string).With!(fn, list));
    assert (table("eins")("passed") == "passed");
}
/** Short form **/
unittest {
    // string
    mixin(dispatchTable!("table", string, string).With!(fn, "eins", fn3));
    assert (table("eins")("passed") == "passed");
    // int
    mixin(dispatchTable!("table2", string, string).With!(fn, 1, fn3));
    assert (table2(1)("passed") == "passed");
    // char
    mixin(dispatchTable!("table3", string, string).With!(fn, 'a', fn3));
    assert (table3('a')("passed") == "passed");
}
/** Check if the arguments are of valid types and in right order

    Should be (string1, func1, string2, func2...)
**/
private auto validArgs (Args...) () {
    import std.meta;
    import std.traits;
    alias Values = getEven!(Args);
    alias Funcs = getUneven!(Args);
    pragma(msg, Values);
    pragma(msg, Funcs);
    template sameType (alias T) {
        static if (is(typeof(T) == typeof(Args[0]))) enum sameType = true;
        else enum sameType = false;
    }
    static if (Values.length == Funcs.length                 // every value has its function
        && (allSatisfy!(isFunction, Funcs))                  // all functions are functions
        && (Values.length == (NoDuplicates!Values).length)   // no duplicate values
        && (allSatisfy!(sameType, Values))                   // all values of same type
        )
        return true;
    else
        return false;
}
unittest {
    import std.meta;
    alias list = AliasSeq!("eins", fn, "zwei", fn2, "drei", fn3);
    alias list2 = AliasSeq!(1, fn, 2, fn2, 3, fn3);
    static assert(validArgs!(list));
    static assert(validArgs!(list2));
    static assert(!validArgs!(AliasSeq!(list,list2)));

}
/** Build the default case **/
private template buildDefault (alias defFn, RT, PT...) {
    static if (is(typeof(defFn) == typeof(null))) {
        enum buildDefault = "default: return null;";
    }
    else
        enum buildDefault = "default: return " ~ _getFunction!(defFn, RT, PT) ~ ";";
}
/** Build the switch cases **/
private template buildCases (RT, PT...) {
    template With (Args...) {
        enum With = buildCasesImpl!(RT, PT).With!("", Args);
    }
}
/** ditto **/
private template buildCasesImpl (RT, PT...) {
    import std.typecons;
    import std.meta;
    import std.algorithm;
    import std.traits;
    template With (string code, Args...) {
        static if (Args.length == 0)
            enum With = code;
        else
            enum With = buildCasesImpl!(RT, PT).With!(code ~ "    " ~ buildCase!(Args[0], Args[1], RT, PT) ~ "\n", Args[2..$]);
    }
}
/** Build string for case **/
private template buildCase (alias Value, alias func, RT, PT...) {
    import std.traits;
    // string
    static if (isSomeString!(typeof(Value)))
        enum ca = "\"" ~ Value ~ "\"";
    // char
    else static if (isSomeChar!(typeof(Value)))
        enum ca = "'" ~ Value ~ "'";
    // numeric
    else static if (isNumeric!(typeof(Value)))
        enum ca = Value.stringof;
    else
        static assert (0, "Invalid switch value!");
    enum buildCase = "case " ~ ca ~ ": return " ~ _getFunction!(func, RT, PT) ~ ";";
}
/** Build the string for the (overloaded) function **/
private template _getFunction (alias func, RT, PT...) {
    import std.traits;
    static if (isOverloaded!func)
        enum _getFunction = "getOverload!(" ~ nameOf!func ~ "," ~ RT.stringof ~ "," ~ PT.stringof[1..$-1] ~ ")";
    else static if (isFunction!func)
        enum _getFunction = "&" ~ nameOf!func;
    else
        static assert(0, "Invalid function argument!");
}



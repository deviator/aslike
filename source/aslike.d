///
module aslike;

import std.traits;
import std.meta;
import std.algorithm : canFind;

private string refPref(alias fn)()
{ return functionAttributes!fn & FunctionAttribute.ref_ ? "ref" : ""; }

private string fnAttr(alias fn, string[] forbidden=[])()
{
    enum f = forbidden ~ "ref";

    template impl(string[] s)
    {
        static if (s.length == 1) enum impl = f.canFind(s[0]) ? "" : s[0];
        else enum impl = impl!(s[0..$/2]) ~ " " ~ impl!(s[$/2..$]);
    }

    return impl!([__traits(getFunctionAttributes, fn)]);
}

///
struct Like(T) if (is(T == interface))
{
    private template dlgName(alias fn) { enum dlgName = "__dlg_" ~ fn.mangleof; }

    private static string buildDelegate(alias fn)()
    {
        enum a1 = dlgName!fn~"_type";
        enum a2 = refPref!fn ~ " ReturnType!fn";
        enum a3 = fnAttr!(fn, ["const", "@property"]);
        enum a4 = dlgName!fn;
        return "private alias "~a1~" = "~a2~" delegate(Parameters!fn) "~a3~";
        private "~a1~" "~a4~";\n";
    }

    private static string buildCall(alias fn, string name)()
    {
        enum a2 = refPref!fn;
        enum a3 = name;
        enum a4 = fnAttr!fn;
        enum a5 = dlgName!fn;
        enum a6 = dlgName!fn~"_args";
        return a2~" ReturnType!fn "~a3~"(Parameters!fn "~a6~") "~a4~
                " { return "~a5~"("~a6~"); }\n";
    }

    alias IT = InterfacesTuple!T;
    static if (IT.length)
    {
        static foreach (it; IT)
        {
            mixin("Like!it as_"~it.stringof~";");
            // Only one alias this allowed by now
            //mixin("alias as_"~IT[0].stringof~" this;");
        }
        static if (IT.length == 1)
            mixin("alias as_"~IT[0].stringof~" this;");
    }

    static foreach (m; [__traits(derivedMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin(buildDelegate!fn ~ buildCall!(fn, m));

    
    void fillDelegatesFrom(bool nullCheck=true, X)(ref X src)
    {
        alias dst = this;

        static if (nullCheck && (is(X == interface) || is(X == class)))
        {
            version (D_BetterC) assert(src !is null, "object is null");
            else enforce(src !is null, "object is null");
        }

        static string buildMakeOrAssign(alias fn, string m)()
        {
            enum dstdlg = "dst." ~ dlgName!fn;
            enum srcm = "src." ~ m;
            static if (hasFunctionAttributes!(fn, "@property") &&
                        !isFunction!(mixin(srcm)))
            {
                enum retsrcm = "return " ~ srcm ~ ";";
                enum pref = refPref!fn;
                static if (arity!fn == 1)
                {
                    enum ret = !is(ReturnType!fn == void);
                    return dstdlg ~ " = "~pref~"(v) { "~srcm~" = v; "~(ret?retsrcm:"")~" };";
                }
                else static if (arity!fn == 0)
                    return dstdlg ~ " = "~pref~" () " ~ fnAttr!(fn, ["@property"]) ~ " { "~retsrcm~" };";
                else
                    static assert(0, "property must have 0 or 1 parameter");
            }
            else return dstdlg ~ " = &"~srcm~";";
        }

        alias IT = InterfacesTuple!T;
        static if (IT.length)
            static foreach (it; IT)
                mixin("this.as_"~it.stringof~".fillDelegatesFrom!nullCheck(src);");
        
        static foreach (m; [__traits(derivedMembers, T)])
            static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
                static foreach (fn; __traits(getOverloads, T, m))
                    mixin(buildMakeOrAssign!(fn, m));
    }
}

///
Like!T as(T, bool nullCheck=true, X)(ref X obj)
    if (is(T == interface))
{
    Like!T ret;
    ret.fillDelegatesFrom!nullCheck(obj);
    return ret;
}


version (D_BetterC) { }
else
{
    import std : format, enforce;

    alias LikeObj(T, S) = LikeWrapper!(T, S, true);

    alias LikeObjCtx(T, S) = LikeWrapper!(T, S, false);

    ///
    class LikeWrapper(T, S, bool isRef=false, string ctxName="__context_", bool isFinal=true) : T
        if (is(T == interface))
    {
        mixin((isFinal?"private":"protected")~" Unqual!S"~(isRef?"*":"")~" "~ctxName~";");

        static if (isRef)
        {
            this(ref Unqual!S c) { mixin(ctxName ~ " = &c;"); }
            this(ref const Unqual!S c) const { mixin(ctxName ~ " = &c;"); }
        }
        else
        {
            this(S c) pure
            {
                static if (__traits(compiles, S.init is null))
                    enforce(c !is null, "context is null");
                mixin(ctxName ~ " = c;");
            }
        }

        private static string buildCall(alias fn, string name)()
        {
            enum args = fn.mangleof ~ "_args";
            enum aref = refPref!fn;

            string callOrFieldUse()
            {
                enum ctxfld = ctxName ~ "." ~ name;
                static if (hasFunctionAttributes!(fn, "@property") &&
                            !isFunction!(typeof(mixin(ctxfld))))
                {
                    enum retctxfld = "return " ~ ctxfld ~ ";";
                    static if (arity!fn == 1)
                    {
                        enum ret = !is(ReturnType!fn == void);
                        return ctxfld~" = "~args~"[0]; "~(ret?retctxfld:"");
                    }
                    else static if (arity!fn == 0) return retctxfld;
                    else static assert(0, "property must have 0 or 1 parameter");
                }
                else return "return " ~ ctxfld ~ "(" ~ args ~ ");";
            }

            return "%7$s override %1$s %2$s ReturnType!fn %3$s(Parameters!fn %4$s) %5$s { %6$s }\n"
                    .format("", aref, name, args, fnAttr!fn, callOrFieldUse(), isFinal ? "final" : "");
        }

        static foreach (m; [__traits(allMembers, T)])
            static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
                static foreach (fn; __traits(getOverloads, T, m))
                    mixin(buildCall!(fn, m));
    }

    ///
    auto toObj(X)(auto ref X th) @property
        if (is(Unqual!X == Like!T, T))
    {
        static if (is(Unqual!X == Like!T, T))
        {
            static if (is(ConstOf!X == X))
                return new const LikeObjCtx!(T, Like!T)(th);
            else
                return new LikeObjCtx!(T, Like!T)(th);
        }
        else static assert(0);
    }

    ///
    auto asObj(T, bool nullCheck=true, X)(ref X obj)
        if (is(T == interface))
    {
        static if (is(ConstOf!X == X))
            return new const LikeObj!(T, X)(obj);
        else
            return new LikeObj!(T, X)(obj);
    }

    ///
    auto asObjCtx(T, bool nullCheck=true, X)(auto ref X obj)
        if (is(T == interface))
    {
        static if (is(ConstOf!X == X))
            return new const LikeObjCtx!(T, X)(obj);
        else
            return new LikeObjCtx!(T, X)(obj);
    }
}

version(unittest)
{
    interface ConstFoo
    {
    @safe:
    nothrow const:
        int one();
        int one(int x);
        int two();

    }

    interface Foo : ConstFoo
    {
    @safe:
        void okda();
    }

    int useFoo(Like!Foo obj) @safe
    {
        obj.okda();
        return obj.one() + obj.two() + obj.one(100);
    }
}

unittest
{
    int k = 1;

    struct Bar
    {
        int a, b;
    @safe:
        void okda() { k = 3; }
    nothrow const:
        int one() { return a * 2 + k; }
        int one(int x) { return a * x; }
        int two() { return a + b; }
    }

    auto bar = Bar(2, 4);
    assert(useFoo(bar.as!Foo) == 213);
    assert(k == 3);
}

unittest
{
    static class Bar : Foo
    {
        void okda() {}
    override const:
        int one() { return 5; }
        int one(int x) { return x * 2; }
        int two() { return 3; }
    }

    auto bar = new Bar;
    assert(useFoo(bar.as!Foo) == 208);
}

unittest
{
    static interface Foo2 { int func() @nogc; }
    static void test(Like!Foo2 obj) @nogc { assert(obj.func() == 42); }

    static class BarC : Foo2
    { override int func() @nogc { return 42; } }

    auto barC = new BarC;
    (() @nogc { test(barC.as!(Foo2, false)); })();

    static struct BarS
    { int func() @nogc { return 42; } }

    BarS barS;
    (() @nogc { test(barS.as!Foo2); })();

    import std : assertThrown;
    BarC nullBarC;
    assertThrown( nullBarC.as!Foo2 );
}

@safe
unittest
{
    static interface Foo3 { int func() @safe; }
    static void test(Like!Foo3 obj) @safe { assert(obj.func() == 42); }

    static class Bar : Foo3
    { override int func() @nogc { return 42; } }

    auto bar = new Bar;
    (() @safe { test(bar.as!Foo3); })();
}

version(unittest)
{
    int useFooObj(Foo obj) @safe
    {
        obj.okda();
        return obj.one() + obj.two() + obj.one(100);
    }

    int useConstFoo(const Like!ConstFoo obj) @safe
    { return obj.one() + obj.two() + obj.one(1000); }

    int useConstFooObj(const ConstFoo obj) @safe
    { return obj.one() + obj.two() + obj.one(1000); }
}

unittest
{
    int k = 1;

    struct Bar
    {
        int a, b;
    @safe:
        void okda() { k = 3; }
    nothrow const:
        int one() { return a * 2 + k; }
        int one(int x) { return a * x; }
        int two() { return a + b; }
    }

    auto bar1 = Bar(2, 4);
    assert(useFooObj(bar1.asObj!Foo) == 213);
    assert(useFooObj(bar1.asObjCtx!Foo) == 213);
    assert(k == 3);
    auto b1 = bar1.as!Foo;
    assert(useFooObj(b1.toObj) == 213);

    assert(useConstFooObj(bar1.asObj!Foo) == 2013);
    assert(useConstFooObj(bar1.asObjCtx!Foo) == 2013);
    auto b2 = bar1.as!Foo;
    assert(useConstFooObj(b2.toObj) == 2013);

    const bar2 = Bar(1, 2);
    assert(useConstFoo(bar2.as!ConstFoo) == 1008);
    auto bb2 = bar2.as!ConstFoo;
    assert(useConstFooObj(bb2.toObj) == 1008);
}

version (unittest)
{
    void testField(I, S)()
    {
        auto s = S(12);
        auto w = s.as!I;

        enum setreturn = is(typeof(I.init.field = 12) == int);

        assert (w.field == 12);
        assert ((cast(const)w).field == 12);
        static if (setreturn) assert ((w.field = 42) == 42);
        else w.field = 42;
        assert (w.field == 42);
        assert ((cast(const)w).field == 42);
        assert (s.field == 42);

        auto o = w.toObj;
        assert (o.field == 42);
        static if (setreturn) assert ((o.field = 50) == 50);
        else o.field = 50;
        assert (w.field == 50);
        assert (s.field == 50);
        assert (o.field == 50);

        auto c = s.asObjCtx!I;
        assert (c.field == 50);
        static if (setreturn) assert ((c.field = 123) == 123);
        else c.field = 123;
        assert (w.field == 50);
        assert (s.field == 50);
        assert (o.field == 50);
        assert (c.field == 123);
    }
}

unittest
{
    static interface F1
    {
        @safe:
        int field() const @property;
        void field(int v) @property;
    }

    static interface F2
    {
        @safe:
        ref const(int) field() const @property;
        ref int field() @property;
        void field(int v) @property;
    }

    static interface F3
    {
        @safe:
        int field() const @property;
        int field(int v) @property;
    }

    struct S1 { int field; }

    static struct S2
    {
        int _field;
        @safe:
        int field() const @property { return _field; }
        void field(int v) @property { _field = v; }
    }

    static struct S3
    {
        int _field;
        @safe:
        int field() const @property { return _field; }
        int field(int v) @property { _field = v; return _field; }
    }

    testField!(F1, S1);
    testField!(F2, S1);
    testField!(F3, S1);

    testField!(F1, S2);
    //testField!(F2, S2);
    //testField!(F3, S2);

    //testField!(F1, S3);
    //testField!(F2, S3);
    testField!(F3, S3);
}

unittest
{
    static interface PFoo
    {
        ref inout(int) field() inout @property;
    }

    struct SPFoo { int field; }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.asObjCtx!PFoo;

    assert (wrap.field == 12);
    wrap.field = 42;
    assert (wrap.field == 42);
    assert (spfoo.field == 12);
    wrap.field = 32;
    assert (wrap.field == 32);
    assert (spfoo.field == 12);
}

///
module aslike;

import std.traits;
import std.meta;
import std.algorithm : canFind, filter;
import std.string : join, format;
import std.exception : enforce;

private mixin template LikeContent(T, string exattr="")
{
    private template dlgName(alias fn) { enum dlgName = "__dlg_" ~ fn.mangleof; }

    private static string fnAttr(alias fn, string[] forbidden=[])()
    {
        enum f = forbidden ~ "ref";
        return [__traits(getFunctionAttributes, fn)].filter!(a=>!f.canFind(a)).join(" ");
    }

    private static string refPref(alias fn)()
    {
        return functionAttributes!fn & FunctionAttribute.ref_ ? "ref" : "";
    }

    private static string buildDelegate(alias fn)()
    {
        enum s = refPref!fn ~ " ReturnType!fn";
        return "private alias %1$s = %2$s delegate(Parameters!fn) %3$s;
        private %1$s %4$s;\n"
                .format(dlgName!fn~"_type", s, fnAttr!(fn, ["const", "@property"]), dlgName!fn);
    }

    private static string buildCall(alias fn, string name)()
    {
        return "%1$s %2$s ReturnType!fn %3$s(Parameters!fn %6$s) %4$s { return %5$s(%6$s); }\n"
                .format(exattr, refPref!fn, name, fnAttr!fn, dlgName!fn, dlgName!fn~"_args");
    }

    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin(buildDelegate!fn ~ buildCall!(fn, m));
}

///
struct Like(T) if (is(T == interface)) { mixin LikeContent!T; }
///
class LikeObj(T) : T if (is(T == interface)) { mixin LikeContent!(T, "final override"); }
///
class LikeObjCtx(T, S) : LikeObj!T { S __context; }

///
T toObj(T)(auto ref const Like!T th) @property
{
    auto ret = new LikeObj!T;

    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin ("ret.%1$s = th.%1$s;".format(th.dlgName!fn));

    return ret;
}

///
void fillLikeDelegates(T, bool nullCheck=true, R, X)(ref R dst, ref X src)
    if (is(T == interface) && (is(R : LikeObj!T) || is(R == Like!T)))
{
    static if (nullCheck && (is(X == interface) || is(X == class)))
        enforce(src !is null, "object is null");

    static string buildMakeOrAssign(alias fn, string m)()
    {
        enum dstdlg = "dst." ~ R.dlgName!fn;
        enum srcm = "src." ~ m;
        static if (hasFunctionAttributes!(fn, "@property") &&
                    !isFunction!(mixin(srcm)))
        {
            enum retsrcm = "return " ~ srcm ~ ";";
            enum pref = R.refPref!fn;
            static if (arity!fn == 1)
            {
                enum ret = !is(ReturnType!fn == void);
                return dstdlg ~ " = "~pref~"(v) { "~srcm~" = v; "~(ret?retsrcm:"")~" };";
            }
            else static if (arity!fn == 0)
            {
                return dstdlg ~ " = "~pref~" () " ~ R.fnAttr!(fn, ["@property"]) ~ " { "~retsrcm~" };";
                //return dstdlg ~ " = "~pref~" () { "~retsrcm~" };";
            }
            else
                static assert(0, "property must have 0 or 1 parameter");
        }
        else
            return dstdlg ~ " = &"~srcm~";";
    }
    
    static foreach (m; [__traits(allMembers, T)])
        static if (__traits(isVirtualFunction, __traits(getMember, T, m)))
            static foreach (fn; __traits(getOverloads, T, m))
                mixin(buildMakeOrAssign!(fn, m));
}

///
Like!T as(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))
{
    Like!T ret;
    fillLikeDelegates!(T,nullCheck)(ret, obj);
    return ret;
}

///
T asObj(T, bool nullCheck=true, X)(ref X obj) if (is(T == interface))
{
    auto ret = new LikeObj!T;
    fillLikeDelegates!(T,nullCheck)(ret, obj);
    return ret;
}

///
T asObjCtx(T, bool nullCheck=true, X)(auto ref X obj) if (is(T == interface))
{
    auto ret = new LikeObjCtx!(T, X);
    ret.__context = obj; // copy context
    fillLikeDelegates!(T,nullCheck)(ret, ret.__context);
    return ret;
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
    assert(k == 3);
    auto b1 = bar1.as!Foo;
    assert(useFooObj(b1.toObj) == 213);

    assert(useConstFooObj(bar1.asObj!Foo) == 2013);
    auto b2 = bar1.as!Foo;
    assert(useConstFooObj(b2.toObj) == 2013);

    const bar2 = Bar(1, 2);
    assert(useConstFoo(bar2.as!ConstFoo) == 1008);
    assert(useConstFooObj(bar2.as!ConstFoo.toObj) == 1008);
}

unittest
{
    static interface PFoo
    {
        int field() const @property;
        void field(int v) @property;
    }

    struct SPFoo { int field; }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.as!PFoo;

    assert (wrap.field == 12);
    wrap.field = 42;
    assert (wrap.field == 42);
    assert (spfoo.field == 42);
    wrap.toObj.field = 32;
    assert (wrap.field == 32);
    assert (wrap.toObj.field == 32);
    assert (spfoo.field == 32);
}

unittest
{
    static interface PFoo
    {
        ref const(int) field() const @property;
        ref int field() @property;
        void field(int v) @property;
    }

    struct SPFoo { int field; }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.as!PFoo;

    assert (wrap.field == 12);
    wrap.field = 42;
    assert (wrap.field == 42);
    assert (spfoo.field == 42);
    wrap.toObj.field = 32;
    assert (wrap.field == 32);
    assert (wrap.toObj.field == 32);
    assert (spfoo.field == 32);
}

unittest
{
    static interface PFoo
    {
        int field() const @property;
        void field(int v) @property;
    }

    struct SPFoo
    {
        int _field;
        int field() const @property { return _field; }
        void field(int v) @property { _field = v; }
    }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.as!PFoo;

    assert (wrap.field == 12);
    wrap.field = 42;
    assert (wrap.field == 42);
    assert (spfoo.field == 42);
    wrap.toObj.field = 32;
    assert (wrap.field == 32);
    assert (wrap.toObj.field == 32);
    assert (spfoo.field == 32);
}

unittest
{
    static interface PFoo
    {
        int field() const @property;
        int field(int v) @property;
    }

    struct SPFoo { int field; }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.as!PFoo;

    assert (wrap.field == 12);
    assert ((wrap.field = 42) == 42);
    assert (wrap.field == 42);
    assert (spfoo.field == 42);
    
    assert ((wrap.toObj.field = 32) == 32);
    assert (wrap.field == 32);
    assert (wrap.toObj.field == 32);
    assert (spfoo.field == 32);
}

pragma(msg, "doesn't support 'inout' attribute yet");
version(none)
unittest
{
    static interface PFoo
    {
        ref inout(int) field() inout @property;
    }

    struct SPFoo { int field; }

    auto spfoo = SPFoo(12);

    auto wrap = spfoo.as!PFoo;

    assert (wrap.field == 12);
    wrap.field = 42;
    assert (wrap.field == 42);
    assert (spfoo.field == 42);
    wrap.toObj.field = 32;
    assert (wrap.field == 32);
    assert (wrap.toObj.field == 32);
    assert (spfoo.field == 32);
}
/+
+/
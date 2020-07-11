/+ dub.sdl:
    dependency "aslike" path="../.."
 +/

// ldc2 -O -I../../source/app.d && rm app.o && ./app

import std.stdio;
import std.typecons : Tuple;
import std.datetime.stopwatch;

import aslike;

interface IFoo
{
    void func1();
    int func2(int, int);
    int func3();
}

struct SFoo
{
    const void delegate() func1;
    const int delegate(int, int) func2;
    const int delegate() func3;
}

struct SFooImplFields
{
    uint func1cnt;
}

SFoo buildSFoo()
{
    SFooImplFields fld;
    return SFoo(
        { fld.func1cnt++; },
        (a,b) => a + b / fld.func1cnt,
        () => fld.func1cnt
    );
}

// classic impl
class IFooImpl : IFoo
{
    int func1cnt;

override:
    void func1() { func1cnt++; }
    int func2(int a, int b) { return a + b / func1cnt; }
    int func3() { return func1cnt; }
}

Tuple!(Duration, int) test(T)(T obj, int N)
{
    auto sw = StopWatch(AutoStart.yes);

    int tmp = 0;
    foreach (i; 0 .. N)
    {
        obj.func1();
        tmp = obj.func2(tmp, i);
        tmp++;
    }

    return typeof(return)(sw.peek(), tmp);
}

void main()
{
    SFoo sfoo = buildSFoo();
    IFoo ifoo = new IFooImpl;
    auto mfoo = (new IFooImpl).as!IFoo;

    enum F = 3;
    const N = 10_000_000;

    Duration[F][] times;

    foreach (i; 0 .. 30)
    {
        auto sres = test(sfoo, N);
        auto ires = test(ifoo, N);
        auto mres = test(mfoo, N);
        times ~= [ sres[0], ires[0], mres[0] ];
        assert (sres[1] == ires[1], "different results");
        assert (mres[1] == ires[1], "different results");
    }
    Duration[F] avg;
    foreach (t; times) foreach (i; 0 .. F) avg[i] += t[i];
    foreach (i; 0 .. F) avg[i] /= times.length;
    stderr.writefln!"delegates avg: [%s]"(avg[0]);
    stderr.writefln!"impliface avg: [%s]"(avg[1]);
    stderr.writefln!"likecache avg: [%s]"(avg[2]);
}
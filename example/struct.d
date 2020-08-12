/+ dub.sdl:
    dependency "aslike" path=".."
 +/

import std.stdio;
import aslike;

interface IntVec
{
    int x() const @property;
    int y() const @property;
}

interface LenCalc
{
    // declare method that use interface through Like wrap
    int len(const Like!IntVec v);
}

class SqrLenCalc : LenCalc
{
    override int len(const Like!IntVec v) { return v.x * v.x + v.y * v.y; }
}

class ManLenCalc : LenCalc
{
    override int len(const Like!IntVec v) { return v.x + v.y; }
}

// this struct can be wrapped into Like!IntVec and used in len method
// of LenCalc because it 'implement' IntVec interface
struct Bar
{
    int _x, _y;
    int x() const @property { return _x; }
    int y() const @property { return _y; }
}

// this class can be wrapped into Like!IntVec too
class Baz : IntVec
{
    int _x, _y;
    this(int X, int Y) { _x = X; _y = Y; }
override:
    int x() const @property { return _x; }
    int y() const @property { return _y; }
}

void main()
{
    auto slc = new SqrLenCalc;
    auto man = new ManLenCalc;
    auto a = Bar(4, 2);
    auto b = new Baz(5, 3);

    writefln("a: sqr len %d, man len %d", slc.len(a.as!IntVec), man.len(a.as!IntVec));
    writefln("b: sqr len %d, man len %d", slc.len(b.as!IntVec), man.len(b.as!IntVec));
}

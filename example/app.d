/+ dub.sdl:
    dependency "aslike" path=".."
 +/

import std.stdio;
import aslike;

interface Foo
{
    int x() const @property;
    int y() const @property;
}

struct Bar
{
    union
    {
        int[2] _data;
        struct { int _x, _y; }
    }

    this(int a, int b) { _x = a; _y = b; }

    int x() const @property { return _data[0]; }
    int y() const @property { return _data[1]; }
}

int sqrLen(const Like!Foo vec) { return vec.x * vec.x + vec.y * vec.y; }

void main()
{
    auto bar = Bar(4, 2);
    writefln("len: %d", bar.as!(Foo).sqrLen);
}
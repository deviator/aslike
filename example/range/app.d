/+ dub.sdl:
    dependency "aslike" path="../.."
 +/

import std.stdio;
import std.range.interfaces;

import aslike;

struct StaticBuffer(size_t N)
{
    char[N] data;
    size_t ln;
    void put(char c)
    {
        assert (ln < N);
        data[ln++] = c;
    }
    void clear() { ln = 0; }
    string getString() const { return data[0..ln].idup; }
}

void print(Like!(OutputRange!char) buf)
{
    foreach (char c; "hello world") buf.put(c);
}

void main()
{
    StaticBuffer!100 buf;

    print(buf.as!(OutputRange!char));

    writeln(buf.getString);
}

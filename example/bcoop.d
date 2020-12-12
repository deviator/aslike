/+ dub.sdl:
    dependency "aslike" path=".."
    dflags "-betterC"
 +/
import aslike;

import core.stdc.stdio;

interface One { ref int func1() return; }
interface Two : One { int func2(); }
interface Three { int func3(); }
interface Four : One, Three {}

void printOne(Like!One one) { printf("one: %d\n", one.func1()); }

void printTwo(Like!Two two)
{
    two.func1() += 33;
    printf("two: %d %d\n", two.func1(), two.func2());
    printOne(two); // alias as_One this;
}

void printThree(Like!Three three) { printf("three: %d\n", three.func3()); }

void printFour(Like!Four four)
{
    printOne(four.as_One);
    printThree(four.as_Three);
}

struct Foo
{
    int a;
    ref int func1() return { return a; }
    int func2() { return 32 + a; }
    int func3() { return 777; }
}

extern (C) int main()
{
    auto foo = Foo(10);
    printTwo(foo.as!Two);
    foo.a = 90;
    printOne(foo.as!One);

    foo.a = 555;
    printFour(foo.as!Four);

    return 0;
}

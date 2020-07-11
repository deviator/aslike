# ASLIKE

`struct Like(T) if (is(T == interface))` -- wrap structure for `T`, it have
methods and private delegate fields matches all methods from `T`.

`Like!T as(T, X)(auto ref X obj) if (is(T == interface))` -- wrapper method,
wrap object `X obj` into `Like!T` if it possible (fill all delegate fields in
returned `Like!T` with methods pointers from `obj`).

It can be helpful if you want to declare function or method what must get some
object as argument, and it object must contains all methods what you want, and
if you don't want use OOP and/or want use structs.

You can use templates for this, but you can't override class methods at this
case, and templace can be less readable what using interface type.

[struct wrap example](example/struct/app.d)

Or if you want cache virtual methods table lookup for improving performance.

[cache wrap example](example/cache/app.d)

## Using

1. define interface

    ```d
    interface Foo
    {
        void func1();
        int func2(int a, int b);
    }
    ```

2. use `Like!Foo` as argument type

    ```d
    int bar(Like!Foo obj, int a, int b)
    {
        obj.func1();
        return obj.func2(a, b);
    }
    ```

3. wrap object by `as` function

    ```d
    struct SFoo
    {
        int field;
        void func1() { field++; }
        int func2(int a, int b) { return a + b / field; }
    }
    ```

    ```
    auto x = SFoo(10);
    writeln(bar(x.as!Foo));
    ```

## Notes

`Like` struct have reference symantics respect to wrapped object.
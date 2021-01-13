---
layout: post
title: "Programming to interface... without paying the cost"
published: true
tag: [C++, Devirtualization, Dependency Inversion Principle, Programming to interface, Test Driven Development]
---
_Programming to interface_ is a fairly good programming practice. It allows decoupling of classes, as stated in
the [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle), as well as
easy testing in context of [Test-driven developpement](https://en.wikipedia.org/wiki/Test-driven_development).
Stricly speaking, there is no _interface_ in C++. Instead, we use inheritance from a base class with no data
member and all its member functions marked as public, pure and virtual[^1]. But calling virtual functions doesn't
come for free, we need to pay the cost of : making an indirect call through the _vtable_, branch (mis)prediction,
instruction cache miss, ... Should we pay this cost just because we want to do things right ? As we will see in
this post, in some cases we could get rid of this price using the power of _Devirtualization_.

[^1]: Others techniques may be used to implement interfaces in C++ (template, ...), but there are out of scope of this article.

Before getting into the technique of devirtualization, let's see what's wrong with the virtual function call with
an exemple. Let's say we need to model a computer with a pretty simple interface `int compute(void)`. To prevent
our computer user to depend on a particular implementation of the computer, we model our computer as an interface,
so computer user only relies on the computer's public API. Doing this eases testing of computer user by allowing us
to provide to the computer user a mock implementation instead of the real computer implementation. Obviously, our
software run the `AllMightyComputer` wich implements the `Computer` interface and of course just return `42`. Bellow
is the corresponding code:

{% highlight C++ linenos %}
class Computer {
public:
    virtual ~Computer() = default;
    
    virtual int compute(void) = 0;
};

class AllMightyComputer : public Computer {
public:
    virtual ~AllMightyComputer() = default;

    int compute(void) override { return 42; }
};

class UserOfComputer {
public:
    UserOfComputer(Computer & aComputer)
    : computer(aComputer)
    { }

    int run(void) { return computer.compute(); }

private:
    Computer & computer;
};

int main(void) {
    AllMightyComputer allMightyComputer;
    UserOfComputer user(allMightyComputer);
    auto result = user.run();

    std::cout << "Answer to life the universe and everything: " << result << std::endl;
    return 0;
}
{% endhighlight %}

_Note: Don't forget to declare interface's destructor as `virtual` to be able to virtualy delete (that is through
a pointer to interface) objects implementing this interface._

Looking at this code, it's obvious that `AllMightyComputer::run()` will finaly be called and just return the
constant 42. So we could reasonably think the compiler will optimize this and just call `operator <<` with the
constant 42... Or maybe not.

## What's wrong with virtual function call ?
So far so good, but what's wrong with this code ? To see the problem, let's look at the assembly code when we
compile it without optimizations ([godbolt](https://godbolt.org/z/5MzE9j)). In particular, the code of
`UserOfComputer` and the main function allocating all objets and injecting dependencies:

{% highlight armasm linenos %}
AllMightyComputer::compute():
    movs    r0, #42
    bx      lr

UserOfComputer::UserOfComputer(Computer&):
    str     r1, [r0]
    bx      lr

UserOfComputer::run() [clone .isra.0]:
    ldr     r3, [r0]
    ldr     r3, [r3, #8]
    bx      r3

main:
    push    {r4, lr}
    sub     sp, sp, #8

    ; Allocate the AllMightyComputer object
    ; That is, storing the address of its vtable on the stack at offset #0
    ldr     r3, .L17
    str     r3, [sp]

    ; Call the UserOfComputer's constructor passing the reference to the Computer
    ; r0 = 'this' pointer of UserOfComputer object (on the stack at offset #4)
    ; r1 = address of vtable of AllMightyComputer
    mov     r1, sp
    add     r0, sp, #4
    bl      UserOfComputer::UserOfComputer(Computer&)

    ; Call UserOfComputer::run() and store result into r4
    ; r0 = this pointer of UserOfComputer object (on the stack at offset #4)
    ldr     r0, [sp, #4]
    bl      UserOfComputer::run() [clone .isra.0]
    mov     r4, r0

    ; Display the text message
    ldr     r1, .L17+4
    ldr     r0, .L17+8
    bl      std::basic_ostream<char, std::char_traits<char> >& std::operator<< <std::char_traits<char> >(std::basic_ostream<char, std::char_traits<char> >&, char const*)

    ; Display the result of call to UserOfComputer::run()
    mov     r1, r4
    bl      std::basic_ostream<char, std::char_traits<char> >::operator<<(int)
    
    ; Display std::endl
    ldr     r1, .L17+12
    bl      std::basic_ostream<char, std::char_traits<char> >::operator<<(std::basic_ostream<char, std::char_traits<char> >& (*)(std::basic_ostream<char, std::char_traits<char> >&))
    
    ; Return 0
    movs    r0, #0
    add     sp, sp, #8
    pop     {r4, pc}

.LC0:
    .ascii  "Answer to life the universe and everything: \000"

.L17:
    .word   vtable for AllMightyComputer
    .word   .LC0
    .word   _ZSt4cout
    .word   _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_

vtable for UserOfComputer::run():
    ; Simplified vtable
    .word   _ZN17AllMightyComputerD1Ev
    .word   AllMightyComputer::~AllMightyComputer() [deleting destructor]
    .word   AllMightyComputer::compute()
{% endhighlight %}

_Note: Following ARM 32bits calling conventions, `this` pointer is passed as first argument (register `r0`), the first
three arguments of the method in registers `r1` to `r3` and the returned value put into `r0`._

The implementation of `AllMightyComputer::compute()` is straight forward, it just returns 42 (in register `r0`)
as expected. From the constructor of `UserOfComputer`, we see that the reference to the computer (argument `r1`) - _in
fact, `r1` contains the address of a pointer to the vtable for `AllMightyComputer`_ - is just stored at `this` address
(argument `r0`). Then when `UserOfComputer::run()` is called, from `this` address (argument `r0`) we restore the
address of the vtable for `AllMightyComputer` into register `r3`. From offset `#8` of `AllMightyComputer`'s vtable,
we load the address of `AllMightyComputer::compute()` method, again into `r3`, and directly branch to it. And finaly,
in the main function we allocate space on stack to store the pointer to the vtable for `AllMightyComputer` and the
`UserOfComputer` object. We call its constructor and then finaly `UserOfComputer::run()`. It's a lot of memory access
(just count the number of memory store `str` / load `ldr` instructions!) and pointers indirecting, just to return 42!

So what can we do to optimize it ?

## Optimizing virtual calls
Fortunately, all _recent_ compilers support an optimization technique named _devirtualization_. In cases like our
example, the compiler knowns that the reference to `Computer` passed to `UserOfComputer` is an instance of
`AllMightyComputer` and nothing else. So, using devirtualization hand in hand with inlining (replacing function
call by there content) and constant propagation techniques, allows the compiler to see that it can replace all
memory accesses and pointer indirection... with the constant 42!

For gcc and clang, the compiler flag used to activate it is `-fdevirtualize` and is included in the `-O2` optimization
level (it even seems to be included at `-O1`...). Let's see the generated assembly with this optimization level
([godbolt](https://godbolt.org/z/ofTzY3)):

{% highlight armasm linenos %}
main:
    push    {r4, lr}
    ldr     r4, .L7

    ; Display the text message
    movs    r2, #44
    ldr     r1, .L7+4
    mov     r0, r4
    bl      std::basic_ostream<char, std::char_traits<char> >& std::__ostream_insert<char, std::char_traits<char> >(std::basic_ostream<char, std::char_traits<char> >&, char const*, int)

    ; Display 42
    movs    r1, #42
    mov     r0, r4
    bl      std::basic_ostream<char, std::char_traits<char> >::operator<<(int)

    ; Display std::endl
    bl      std::basic_ostream<char, std::char_traits<char> >& std::endl<char, std::char_traits<char> >(std::basic_ostream<char, std::char_traits<char> >&)
    
    ; Return 0
    movs    r0, #0
    pop     {r4, pc}

.LC0:
    .ascii  "Answer to life the universe and everything: \000"

.L7:
    .word   _ZSt4cout
    .word   .LC0
{% endhighlight %}

Now, we have an assembly that look like what we expected at first sight! The compiler has generated (lines 12 to 14) a
simple call to `operator <<` with the constant value `42`. And that's all!

This was a really simple example and compiler did a very good job without developer hint. But in real code, this may
not work as easily.

## Helping the compiler
In this basic example, it was quite easy for the compiler to devirtualize the call to the virtual method. In real world
code, the challenge could be lot more harder. To help the compiler get the most out of your code, C++11 introduce a new
keyword named `final`. Virtual function could be marked as `final` in order to tell the compiler that this function will
not be overwritten by derived classes. Here is what it look likes for our example:

{% highlight C++ linenos %}
class AllMightyComputer : public Computer {
public:
    virtual ~AllMightyComputer() = default;

    int compute(void) override final { return 42; }
};
{% endhighlight %}

Furthermore, the `final` keyword could be applied to the whole class instead of virtual functions. In this case, the class
as a whole can't be derived, she's sealed. It could be used like this:

{% highlight C++ linenos %}
class AllMightyComputer final : public Computer {
public:
    virtual ~AllMightyComputer() = default;

    int compute(void) override { return 42; }
};
{% endhighlight %}

Using the `final` keyword could help the compiler to apply devirtualization in situation where this is not obvious.

## Optimizing across translation units
In this example, all of the classes were put into the same source file. Also, all functions are defined inline. Again,
in real world code, this is not the case. Good practices suggest to put separate classes into separate files (a
particular case of the _Single Responsibility Principle_: one file = one class = one responsibility), as well as to
separate declaration (in header file) from definition (in cpp file). Doing this could prevent the compiler to apply
optimizations like devirtualization, inlining and so accross the whole program.

To circumvent this problem, compilers implements a technique called _Link Time Optimization_ wich allows trying to apply
above optimizations at link time, that is to say for the whole program. Under gcc/clang, the option is named `-flto` and
could be used like this:

{% highlight shell linenos %}
g++ -c -O2 -flto AllMightyComputer.cpp
g++ -c -O2 -flto UserOfComputer.cpp
g++ -c -O2 -flto main.cpp
g++ -o prog -O2 -flto AllMightyComputer.o UserOfComputer.o main.o
{% endhighlight %}

Notice that, even at link time (line 4), `g++` should
 be used instead of the classical `ld`. Also, when linking a static
library built with LTO option, add the flag `-fuse-linker-plugin` (gcc only) to tell gcc to include the library into the
global optimisations.

{% highlight shell linenos %}
g++ -o prog -O2 -flto -fuse-linker-plugin AllMightyComputer.o UserOfComputer.o main.o libOptimizedWithLTO.a
{% endhighlight %}

_Link Time Optimization_ is an heavy process, memory and time consuming. To mitigate this, don't hesitate to look at compiler
documentation to activate options that speedup link time: paralellizing link, using _thin_ LTO, ...

## Conclusion
Good coders apply good pratices: _Programming to interface_ (or _Dependency Inversion Principle_), putting distinct
classes into distinct files, separating declaration from definition, ... But in C++, this good practices may lead to
performance penalties, even more in embedded code. Fortunately, today's compilers are able to mitigate this penalty or
even remove it completely using techniques such as _inlining_, _devirtualization_ or _link time optimization_. So help
your compiler by giving it optimization options (`-O2`, `-O3`, `-flto`) and code hints (`final` keyword) ; so that in
return, your compiler will help you to be a good coder.

> Help your compiler by giving it optimization options (`-O2`, `-O3`, `-flto`, ...) and code hints (`final` keyword) ;
> so that in return, your compiler will help you to be a good coder.
{:.yoda-quote}

----
## Related articles
- [The Performance Benefits of Final Classes](https://devblogs.microsoft.com/cppblog/the-performance-benefits-of-final-classes/) by Sy Brand
- [C++ Devirtualization](http://lazarenko.me/devirtualization/) by Vlad Lazarenko
- [The power of devirtualization](https://marcofoco.com/the-power-of-devirtualization/) by Marco Foco
- [Devirtualization in C++](http://hubicka.blogspot.com/2014/01/devirtualization-in-c-part-1.html) series by Honza Hubička
- [Virtual, final and override in C++](https://www.fluentcpp.com/2020/02/21/virtual-final-and-override-in-cpp/) by Jonathan Boccara

----

---
layout: post
title: "Resource owning - Part 2 : Rule of five"
tag: [C++]
---
In the first part of this series on _resource owning_, we've seen that separating resource owning from business
code is a good practice. We've also seen that if one of destructor, copy constructor or copy assignment operator
is defined, all of them must also be defined, as stated by the [Rule of three](https://en.cppreference.com/w/cpp/language/rule_of_three).
In this part, we'll get into the move semantic introduced by C++11 and cover the case of _moving_ a resource
owning object into another. But before that, we'll fix the 3 issues of our first implementation.

This post is part of a series about _Resource owning_:
* [Resource owning - Part 1 : _Rule of three_]({{ site.baseurl }}{% post_url 2018-07-20-resource-owning-1 %})
* [Resource owning - Part 2 : _Rule of five_]({{ site.baseurl }}{% post_url 2018-07-31-resource-owning-2 %})
* Resource owning - Part 3 : _Rule of zero_

Let's first remind our use case of a circular buffer class and particulary the implementation we ended with:
{% highlight C++ linenos %}
Buffer::~Buffer(void)
{
    delete [] data;
}

Buffer::Buffer(const Buffer & buffer)
: data(buffer.capacity ? new uint8_t[buffer.capacity] : nullptr)
, capacity(buffer.capacity)
, start(buffer.start)
, end(buffer.end)
{
    std::copy_n(buffer.data, capacity, data);
}

Buffer & Buffer::operator =(const Buffer & buffer)
{
    // Prevent self assignment
    if(&buffer != this)
        return *this;

    // Cleanup old data (1)
    delete [] data;

    // Allocate new one (2)
    data     = buffer.capacity ? new uint8_t[buffer.capacity] : nullptr;
    // ---- Below this line, we're exception safe ---- (3)
    capacity = buffer.capacity;
    start    = buffer.start;
    end      = buffer.end;
    std::copy_n(buffer.data, capacity, data);

    return *this;
}
{% endhighlight %}

In the first part, we noticed that this implementation of the copy assignment operator suffers from 3 issues:
* First, this implementation don't offer any exception guarantee. If the `new` operator, line 25, throws, our
`Buffer` object will fall into a invalid state.
* Also, on line 18, we test for self-assignment which is a very rare case. Why should we pay each time for a
case that occurs so unfrequently ?
* And finally, most of the code is a duplication of the destructor and copy constructor. And I hate [repeat
myself](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) ;-)

So let's start with some exception safety.

## Exception safety
The problem here comes from the order of operations. We first release the current buffer (1) and then allocate
the new one (2). And if we fail at (2), we loosed the old buffer. Looking closer to this function, we can
distinguish two parts. The upper part (starting from function entry to (3)) contains code that may throw. This
is the _Exception Unsafety Zone_. The lower one (starting from (3) until the end of function), instead contains
only _safe code_, that means, code that can NOT throw (`std::copy_n()` doesn't throw). Let's call it the
_Exception Safety Zone_. The two part are separated by the _exception safety line_. The goals here, is to avoid
modifying our object state before we cross the _exception safety line_. This is a lot easier if we rise up the
line to maximize the _Exception Safety Zone_ and so minimize the unsafety one. So in our case, to solve our
exception safety problem the solution is quite simple: try to allocate the new buffer first, and then release
the old one if succeed.

{% highlight C++ linenos %}
Buffer & Buffer::operator =(const Buffer & buffer)
{
    if(&buffer != this)
        return *this;

    // Get the new data ready before we replace the old (1)
    uint8_t * newdata     = buffer.capacity ? new uint8_t[buffer.capacity] : nullptr;
    // ---- Below this line, we're exception safe ---- (3)
    size_t    newcapacity = buffer.capacity;
    int       newstart    = buffer.start;
    int       newend      = buffer.end;
    std::copy_n(buffer.data, newcapacity, newdata);

    // Delete old data (non-throwing) (2)
    delete [] data;

    // Replace the old data (all are non-throwing) (4)
    data     = newdata;
    capacity = newcapacity;
    start    = newstart;
    end      = newend;

    return *this;
}
{% endhighlight %}

Now, our assignment operator is safe from the exception point of view. If the `new` operator throw, the old data
is preserved.

And with this version, a new code structure shows up. In (1), we likely copy construct a new temporary buffer
from the passed argument. Then, if we succeed, we delete the old buffer (2). And finally, we transfer the
temporary buffer into the current object (4).

## Copy and swap idiom
We can refactor a little bit this code in order to leverage usage of our existing functions. We can replace (1)
by calling the copy-constructor to create a local temporary object ('temporary' here means that it will be
destroyed at function end). To replace (2) with a call to a destructor, we can take advantage of the fact that
the local temporary object will be destroyed at the end of the function. So, we just have to transfer the
current object content to the local one, and it will automaticaly be destroyed. And finaly, looking at (4), we
also have to transfer the content of the local object into the current one. Putting all this things together, we
need a function that _exchange_ (or _swap_) the current content of a `Buffer` with another one passed in
argument. The following code snippet shows an implementation of such a function.

{% highlight C++ linenos %}
void Buffer::swap(Buffer & buffer) noexcept
{
   std::swap(data,     buffer.data);
   std::swap(capacity, buffer.capacity);
   std::swap(start,    buffer.start);
   std::swap(end,      buffer.end);
}
{% endhighlight %}

This make an heavy use of the `std::swap()` function in order to individually swap all `Buffer` data members.
This helper function allows us to have a really clean assignment operator (see the code below), far more easy
to read than the previous version. The resulting 3 steps (copy, swap, destroy) assignment operator is another
well known good practice, named the [Copy and swap idiom](https://en.wikibooks.org/wiki/More_C%2B%2B_Idioms/Copy-and-swap).

{% highlight C++ linenos %}
Buffer & Buffer::operator =(const Buffer & buffer)
{
    Buffer temp(buffer);
    // ---- Below this line, we're exception safe ---- (3)
    swap(temp);

    return *this;
}
{% endhighlight %}

Also, one thing to be carefull of, is that `swap()` have to be exception-free in order to keep the _exception
safety line_ as up as possible.

With this copy-and-swap version, not only is our assignment operator exception-safe, but it also fix the two
other issues. Instead of paying for a test for self-assignment every time it's not a self-assignment, we only
pay for an extra copy in case of a self-assignment. So we pay only in extremly rare case. We also avoid lot of
duplicated code, wihch is also a good thing. The following code shows a summary of our current `Buffer` class.

{% highlight C++ linenos %}
class Buffer
{
public:
    explicit Buffer(size_t _capacity)
    : data(_capacity ? new uint8_t[_capacity] : nullptr)
    , capacity(_capacity)
    , start(-1)
    , end(-1)
    { }

    ~Buffer(void)
    {
        delete [] data;
    }

    Buffer(const Buffer & buffer)
    : data(buffer.capacity ? new uint8_t[buffer.capacity] : nullptr)
    , capacity(buffer.capacity)
    , start(buffer.start)
    , end(buffer.end)
    {
        std::copy_n(buffer.data, capacity, data);
    }

    Buffer & operator =(const Buffer & buffer)
    {
        Buffer temp(buffer);
        swap(temp);

        return *this;
    }

    void swap(Buffer & buffer) noexcept
    {
        std::swap(data,     buffer.data);
        std::swap(capacity, buffer.capacity);
        std::swap(start,    buffer.start);
        std::swap(end,      buffer.end);
    }

private:
    uint8_t * data;
    size_t    capacity;
    int       start;
    int       end;
};
{% endhighlight %}

Now, let's see what our `Buffer` class looks like in a C++11 context.

## The rule of five
C++11 introduce a new semantic named the _move semantic_. The idea behind move semantic is that sometimes we
create an object, maybe use it, and then _pass_ it to another function or object, and never use it after that.
Before C++11, we add two options. We can pass it by value, but this involved a deep copy of an object that won't
be used anymore. This wasn't very efficient, mostly on big objects. If we wanted to avoid the deep copy, we
could pass the object by reference, but we needed to maintain it alive in the caller, which could be very
tedious. With C++11, we can pass it by _r-value_ reference (using `&&` syntax), which means that we want to
_move_ the passed value. So, for our `Buffer` class, if we want to support the move semantic we need to manualy
write (instead of compiler generated) two more functions: the _move constructor_ and the _move assignment
operator_. So the good practice of the [Rule of three](https://en.cppreference.com/w/cpp/language/rule_of_three)
has been completed by the [Rule of five](https://en.cppreference.com/w/cpp/language/rule_of_three#Rule_of_five)
that states:

> If a class requires:
> <ul>
>     <li>a user-defined destructor,</li>
>     <li>a user-defined copy constructor,</li>
>     <li>a user-defined copy assignment operator,</li>
>     <li>a user-defined move constructor,</li>
>     <li>or a user-defined move assignment operator,</li>
> </ul>, it almost certainly requires all five.
{:.blockquote .yoda}

This lead to the following implementation for our `Buffer` class.

{% highlight C++ linenos %}
Buffer::Buffer(Buffer && buffer) noexcept
: Buffer(0)
{
    swap(buffer);
}

Buffer & Buffer::operator =(Buffer && buffer)
{
    Buffer temp(std::move(buffer));
    swap(temp);

    return *this;
}
{% endhighlight %}

Notice that when moving an object, the standard says that the _moved-from_ object must be leaved in a valid
state. For our `Buffer` object, that means that we must at least set the `data`, `capacity`, `start` and `end`
data members to a valid value. So, for the move constructor, we initialize our current buffer with a capacity
of `0` and then just swap it with the `buffer` argument. For the move assignment operator, we reuse the copy
and swap pattern, but this time instead of copying the passed argument into the local object, we move it to
the local object. Then swap it with the current buffer and destroy it at the end of the function.

So, we end up with the following implementation for our C++11 compliant `Buffer` class:

{% highlight C++ linenos %}
class Buffer
{
public:
    explicit Buffer(size_t _capacity)
    : data(_capacity ? new uint8_t[_capacity] : nullptr)
    , capacity(_capacity)
    , start(-1)
    , end(-1)
    { }

    ~Buffer(void)
    {
        delete [] data;
    }

    Buffer(const Buffer & buffer)
    : data(buffer.capacity ? new uint8_t[buffer.capacity] : nullptr)
    , capacity(buffer.capacity)
    , start(buffer.start)
    , end(buffer.end)
    {
        std::copy_n(buffer.data, capacity, data);
    }

    Buffer(Buffer && buffer) noexcept
    : Buffer(0)
    {
        swap(buffer);
    }

    Buffer & operator =(const Buffer & buffer)
    {
        Buffer temp(buffer);
        swap(temp);

        return *this;
    }

    Buffer & operator =(Buffer && buffer)
    {
        Buffer temp(std::move(buffer));
        swap(temp);

        return *this;
    }

    void swap(Buffer & buffer) noexcept
    {
        std::swap(data,     buffer.data);
        std::swap(capacity, buffer.capacity);
        std::swap(start,    buffer.start);
        std::swap(end,      buffer.end);
    }

private:
    uint8_t * data;
    size_t    capacity;
    int       start;
    int       end;
};
{% endhighlight %}

Looking at both (copy and move) assignment operator, we see again a lot of duplicated code. The only difference
is the way (by copy or by move) we construct the local object. But again, don't worry, we will fix that in the
next part of the series: "_Resource owning - Part 3 : Rule of zero_".

## Conclusion
Today, we have seen some other good practices associated with resource owning. [Copy and swap idiom](https://en.wikibooks.org/wiki/More_C%2B%2B_Idioms/Copy-and-swap)
is a good way to enforce exception safety and have a lot more readable and clean code. Also, if one of
destructor, copy constructor, copy assignment, move constructor, or move assignment operator is defined, all of
them must also be defined, as stated by the [Rule of five](https://en.cppreference.com/w/cpp/language/rule_of_three#Rule_of_five).